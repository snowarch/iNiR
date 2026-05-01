#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


PRESETS = ("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")


@dataclass(frozen=True)
class MediaInfo:
    duration: float
    size_bytes: int
    width: int
    height: int
    has_audio: bool


@dataclass(frozen=True)
class EncodePlan:
    budget_bytes: int
    video_kbps: int
    audio_kbps: int
    width: int
    height: int


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def require_binary(name: str) -> str:
    path = shutil.which(name)
    if not path:
        fail(f"{name} is required but was not found in PATH")
    return path


def run_json(command: list[str]) -> dict:
    proc = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
    if proc.returncode != 0:
        detail = "\n".join(proc.stderr.splitlines()[-8:])
        fail(detail or f"{command[0]} failed")
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        fail("ffprobe returned invalid JSON")


def probe_media(ffprobe: str, input_path: Path) -> MediaInfo:
    payload = run_json([
        ffprobe,
        "-v", "error",
        "-show_entries", "format=duration:stream=codec_type,width,height",
        "-of", "json",
        str(input_path),
    ])
    duration = float(payload.get("format", {}).get("duration") or 0)
    width = 0
    height = 0
    has_audio = False
    for stream in payload.get("streams", []):
        codec_type = stream.get("codec_type")
        if codec_type == "video" and width <= 0:
            width = int(stream.get("width") or 0)
            height = int(stream.get("height") or 0)
        elif codec_type == "audio":
            has_audio = True
    if duration <= 0:
        fail("Could not detect video duration")
    if width <= 0 or height <= 0:
        fail("Could not detect video dimensions")
    return MediaInfo(duration, input_path.stat().st_size, width, height, has_audio)


def even(value: float) -> int:
    return max(2, int(value) // 2 * 2)


def scaled_size(info: MediaInfo, video_kbps: int, requested_max_dimension: int) -> tuple[int, int]:
    max_dimension = max(240, requested_max_dimension)
    if video_kbps < 180:
        max_dimension = min(max_dimension, 540)
    elif video_kbps < 300:
        max_dimension = min(max_dimension, 720)
    elif video_kbps < 600:
        max_dimension = min(max_dimension, 960)
    elif video_kbps < 1100:
        max_dimension = min(max_dimension, 1280)

    source_long_edge = max(info.width, info.height)
    if source_long_edge <= max_dimension:
        return even(info.width), even(info.height)

    ratio = max_dimension / source_long_edge
    return even(info.width * ratio), even(info.height * ratio)


def build_plan(info: MediaInfo, budget_bytes: int, audio_kbps: int, max_dimension: int) -> EncodePlan:
    total_bps = max(1000, budget_bytes * 8 / info.duration)
    audio_bps = 0
    if info.has_audio and audio_kbps > 0:
        requested_audio_bps = audio_kbps * 1000
        audio_bps = min(requested_audio_bps, total_bps * 0.25)
        if total_bps >= 140_000:
            audio_bps = max(32_000, audio_bps)
        elif total_bps >= 70_000:
            audio_bps = max(20_000, audio_bps)
        else:
            audio_bps = max(0, total_bps * 0.16)
        audio_bps = min(audio_bps, total_bps * 0.45)

    video_bps = max(1000, total_bps - audio_bps)
    video_kbps = max(1, math.floor(video_bps / 1000))
    final_audio_kbps = max(0, math.floor(audio_bps / 1000))
    width, height = scaled_size(info, video_kbps, max_dimension)
    return EncodePlan(budget_bytes, video_kbps, final_audio_kbps, width, height)


def ffmpeg_error(stderr: str, fallback: str) -> RuntimeError:
    detail = "\n".join((stderr or "").splitlines()[-12:])
    return RuntimeError(detail or fallback)


def run_ffmpeg(command: list[str], quiet: bool) -> None:
    proc = subprocess.run(
        command,
        stdout=subprocess.DEVNULL if quiet else None,
        stderr=subprocess.PIPE if quiet else None,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise ffmpeg_error(proc.stderr or "", f"{command[0]} failed with exit code {proc.returncode}")


def video_args(plan: EncodePlan, preset: str, info: MediaInfo) -> list[str]:
    args = [
        "-map", "0:v:0",
        "-sn",
        "-c:v", "libx264",
        "-preset", preset,
        "-b:v", f"{plan.video_kbps}k",
        "-maxrate", f"{plan.video_kbps}k",
        "-bufsize", f"{max(plan.video_kbps * 2, 2)}k",
        "-pix_fmt", "yuv420p",
    ]
    if plan.width != even(info.width) or plan.height != even(info.height):
        args += ["-vf", f"scale={plan.width}:{plan.height}:flags=lanczos"]
    return args


def encode_attempt(ffmpeg: str, input_path: Path, output_path: Path, temp_output: Path, info: MediaInfo, plan: EncodePlan, preset: str, passlog: Path, quiet: bool) -> None:
    common = [ffmpeg, "-hide_banner", "-nostdin", "-y", "-i", str(input_path)]
    first_pass = common + video_args(plan, preset, info) + [
        "-pass", "1",
        "-passlogfile", str(passlog),
        "-an",
        "-f", "null",
        os.devnull,
    ]
    second_pass = common + video_args(plan, preset, info) + [
        "-pass", "2",
        "-passlogfile", str(passlog),
    ]
    if info.has_audio and plan.audio_kbps > 0:
        second_pass += ["-map", "0:a:0?", "-c:a", "aac", "-b:a", f"{plan.audio_kbps}k", "-ac", "2"]
    else:
        second_pass += ["-an"]
    second_pass += ["-map_metadata", "0", "-movflags", "+faststart", str(temp_output)]

    temp_output.unlink(missing_ok=True)
    run_ffmpeg(first_pass, quiet)
    run_ffmpeg(second_pass, quiet)
    if not temp_output.exists() or temp_output.stat().st_size <= 0:
        raise RuntimeError("ffmpeg did not create an output file")
    os.replace(temp_output, output_path)


def default_output_path(input_path: Path) -> Path:
    return input_path.with_name(f"{input_path.stem}.discord.mp4")


def compress(args: argparse.Namespace) -> dict:
    try:
        os.nice(max(0, args.nice))
    except OSError:
        pass

    ffmpeg = require_binary("ffmpeg")
    ffprobe = require_binary("ffprobe")
    input_path = Path(args.input).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve() if args.output else default_output_path(input_path)
    if not input_path.is_file():
        fail(f"Input file does not exist: {input_path}")
    if input_path == output_path:
        fail("Output path must be different from input path")

    target_bytes = max(1, int(args.target_mb * 1_000_000))
    budget_mb = max(0.1, args.target_mb - max(0.0, args.safety_margin_mb))
    budget_bytes = min(target_bytes, max(1, int(budget_mb * 1_000_000)))
    output_path.parent.mkdir(parents=True, exist_ok=True)

    info = probe_media(ffprobe, input_path)
    if not args.force and info.size_bytes <= target_bytes:
        return {
            "status": "skipped",
            "reason": "already_under_target",
            "input": str(input_path),
            "output": str(input_path),
            "sizeBytes": info.size_bytes,
            "targetBytes": target_bytes,
        }

    temp_output = output_path.with_name(f".{output_path.stem}.tmp-{os.getpid()}{output_path.suffix or '.mp4'}")
    last_error = None
    with tempfile.TemporaryDirectory(prefix="inir-discord-compress-") as temp_dir:
        for attempt in range(max(0, args.retries) + 1):
            attempt_budget = max(1, int(budget_bytes * (0.88 ** attempt)))
            plan = build_plan(info, attempt_budget, args.audio_kbps, args.max_dimension)
            passlog = Path(temp_dir) / f"pass-{attempt}"
            try:
                encode_attempt(ffmpeg, input_path, output_path, temp_output, info, plan, args.preset, passlog, args.quiet)
                size_bytes = output_path.stat().st_size
                if size_bytes <= target_bytes:
                    return {
                        "status": "compressed",
                        "input": str(input_path),
                        "output": str(output_path),
                        "sizeBytes": size_bytes,
                        "targetBytes": target_bytes,
                        "videoKbps": plan.video_kbps,
                        "audioKbps": plan.audio_kbps,
                        "width": plan.width,
                        "height": plan.height,
                        "attempt": attempt + 1,
                    }
                last_error = RuntimeError(f"output exceeded target ({size_bytes} > {target_bytes})")
                output_path.unlink(missing_ok=True)
            except RuntimeError as error:
                last_error = error
                temp_output.unlink(missing_ok=True)
            finally:
                for file in Path(temp_dir).glob(f"{passlog.name}*"):
                    file.unlink(missing_ok=True)

    fail(str(last_error or "compression failed"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Compress a video into a Discord-friendly size budget.")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output")
    parser.add_argument("--target-mb", type=float, default=10.0)
    parser.add_argument("--safety-margin-mb", type=float, default=0.5)
    parser.add_argument("--audio-kbps", type=int, default=96)
    parser.add_argument("--preset", choices=PRESETS, default="slow")
    parser.add_argument("--max-dimension", type=int, default=1280)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--nice", type=int, default=5)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = compress(args)
    print(json.dumps(result, separators=(",", ":")) if args.json else result["output"])


if __name__ == "__main__":
    main()
