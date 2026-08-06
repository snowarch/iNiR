#!/usr/bin/env python3
"""Provider-neutral speech-to-text adapter for iNiR.

Secrets are read from INIR_VOICE_API_KEY and never placed in argv. The script
prints only the transcription on stdout; diagnostics go to stderr.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import uuid
from typing import Any


def _json_request(
    url: str,
    *,
    headers: dict[str, str] | None = None,
    data: bytes | None = None,
    method: str | None = None,
    timeout: float = 60.0,
) -> Any:
    request = urllib.request.Request(
        url,
        data=data,
        headers=headers or {},
        method=method,
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def _multipart(fields: dict[str, str], file_path: Path) -> tuple[bytes, str]:
    boundary = "----inir-voice-" + uuid.uuid4().hex
    chunks: list[bytes] = []
    for name, value in fields.items():
        chunks.extend(
            [
                f"--{boundary}\r\n".encode(),
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
                str(value).encode(),
                b"\r\n",
            ]
        )
    mime = mimetypes.guess_type(file_path.name)[0] or "audio/wav"
    chunks.extend(
        [
            f"--{boundary}\r\n".encode(),
            (
                f'Content-Disposition: form-data; name="file"; '
                f'filename="{file_path.name}"\r\n'
            ).encode(),
            f"Content-Type: {mime}\r\n\r\n".encode(),
            file_path.read_bytes(),
            b"\r\n",
            f"--{boundary}--\r\n".encode(),
        ]
    )
    return b"".join(chunks), boundary


def _openai_compatible(
    file_path: Path,
    endpoint: str,
    model: str,
    key: str,
    language: str,
) -> str:
    fields = {"model": model, "response_format": "json"}
    if language and language != "auto":
        fields["language"] = language
    body, boundary = _multipart(fields, file_path)
    payload = _json_request(
        endpoint,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Accept": "application/json",
            "User-Agent": "iNiR/Voice",
        },
        data=body,
        method="POST",
    )
    return str(payload.get("text") or "").strip()


def _gemini(file_path: Path, model: str, key: str) -> str:
    mime = mimetypes.guess_type(file_path.name)[0] or "audio/wav"
    size = file_path.stat().st_size
    start_request = urllib.request.Request(
        "https://generativelanguage.googleapis.com/upload/v1beta/files",
        data=json.dumps({"file": {"display_name": "iNiR voice"}}).encode(),
        headers={
            "x-goog-api-key": key,
            "X-Goog-Upload-Protocol": "resumable",
            "X-Goog-Upload-Command": "start",
            "X-Goog-Upload-Header-Content-Length": str(size),
            "X-Goog-Upload-Header-Content-Type": mime,
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(start_request, timeout=30) as response:
        upload_url = response.headers.get("X-Goog-Upload-URL", "")
    if not upload_url:
        raise RuntimeError("Gemini did not return an upload URL")

    upload_request = urllib.request.Request(
        upload_url,
        data=file_path.read_bytes(),
        headers={
            "x-goog-api-key": key,
            "Content-Length": str(size),
            "X-Goog-Upload-Offset": "0",
            "X-Goog-Upload-Command": "upload, finalize",
            "Content-Type": mime,
        },
        method="POST",
    )
    with urllib.request.urlopen(upload_request, timeout=60) as response:
        upload_result = json.loads(response.read().decode("utf-8"))
    file_uri = upload_result.get("file", {}).get("uri", "")
    if not file_uri:
        raise RuntimeError("Gemini upload did not return a file URI")

    generation_url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        + urllib.parse.quote(model, safe="-._")
        + ":generateContent?key="
        + urllib.parse.quote(key)
    )
    payload = {
        "contents": [
            {
                "parts": [
                    {"file_data": {"mime_type": mime, "file_uri": file_uri}},
                    {
                        "text": (
                            "Transcribe this audio exactly. Output only the "
                            "transcription. If it is empty or unclear, output nothing."
                        )
                    },
                ]
            }
        ],
        "generationConfig": {"temperature": 0},
    }
    result = _json_request(
        generation_url,
        headers={"Content-Type": "application/json", "User-Agent": "iNiR/Voice"},
        data=json.dumps(payload).encode(),
        method="POST",
    )
    candidates = result.get("candidates") or []
    if not candidates:
        return ""
    parts = candidates[0].get("content", {}).get("parts") or []
    return "".join(str(part.get("text") or "") for part in parts).strip()


def _candidate_local_models(explicit: str) -> list[Path]:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit).expanduser())
    home = Path.home()
    data_home = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", home / ".cache"))
    candidates.extend(
        [
            data_home / "inir/whisper/ggml-base.bin",
            data_home / "whisper/ggml-base.bin",
            cache_home / "whisper.cpp/ggml-base.bin",
            cache_home / "whisper/ggml-base.bin",
        ]
    )
    return candidates


def _probe_local(explicit_model: str) -> dict[str, Any]:
    executable = shutil.which("whisper-cli") or shutil.which("whisper-cpp")
    model = next((path for path in _candidate_local_models(explicit_model) if path.is_file()), None)
    return {
        "available": bool(executable and model),
        "executable": executable or "",
        "model": str(model) if model else "",
    }


def _local_whisper(file_path: Path, model_path: str, language: str) -> str:
    probe = _probe_local(model_path)
    if not probe["available"]:
        raise RuntimeError("whisper-cli or a local ggml model is missing")
    with tempfile.TemporaryDirectory(prefix="inir-voice-") as temp_dir:
        output_base = Path(temp_dir) / "transcript"
        command = [
            probe["executable"],
            "-m",
            probe["model"],
            "-f",
            str(file_path),
            "-otxt",
            "-of",
            str(output_base),
            "-nt",
        ]
        if language and language != "auto":
            command.extend(["-l", language])
        completed = subprocess.run(
            command,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=180,
        )
        if completed.returncode != 0:
            raise RuntimeError(completed.stderr.strip() or "whisper-cli failed")
        transcript_file = output_base.with_suffix(".txt")
        if transcript_file.is_file():
            return transcript_file.read_text(encoding="utf-8").strip()
        return completed.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", choices=["probe", "local", "groq", "openai", "gemini"], required=True)
    parser.add_argument("--audio", default="")
    parser.add_argument("--endpoint", default="")
    parser.add_argument("--model", default="")
    parser.add_argument("--language", default="auto")
    parser.add_argument("--local-model", default="")
    args = parser.parse_args()

    if args.provider == "probe":
        print(json.dumps(_probe_local(args.local_model), separators=(",", ":")))
        return 0

    audio_path = Path(args.audio).expanduser()
    if not audio_path.is_file() or audio_path.stat().st_size == 0:
        print("Audio file is missing or empty", file=sys.stderr)
        return 2

    key = os.environ.get("INIR_VOICE_API_KEY", "")
    try:
        if args.provider == "local":
            transcript = _local_whisper(audio_path, args.local_model, args.language)
        elif args.provider == "gemini":
            if not key:
                raise RuntimeError("Gemini key is missing")
            transcript = _gemini(audio_path, args.model or "gemini-2.5-flash", key)
        else:
            if not key:
                raise RuntimeError("Provider key is missing")
            transcript = _openai_compatible(
                audio_path,
                args.endpoint,
                args.model,
                key,
                args.language,
            )
        print(transcript)
        return 0
    except (urllib.error.URLError, urllib.error.HTTPError, RuntimeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    finally:
        try:
            audio_path.unlink(missing_ok=True)
        except OSError:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
