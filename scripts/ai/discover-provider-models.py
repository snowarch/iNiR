#!/usr/bin/env python3
"""Discover and normalize AI models without exposing provider secrets in argv."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

UNKNOWN = "unknown"
SUPPORTED = "supported"
UNSUPPORTED = "unsupported"


def _request_json(url: str, headers: dict[str, str], timeout: float) -> Any:
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def _capabilities(**overrides: str) -> dict[str, str]:
    result = {
        "chat": SUPPORTED,
        "vision": UNKNOWN,
        "audioInput": UNKNOWN,
        "toolCalling": UNKNOWN,
        "webSearch": UNKNOWN,
        "structuredOutput": UNKNOWN,
        "reasoning": UNKNOWN,
    }
    result.update(overrides)
    return result


def _modalities(raw: Any) -> list[str]:
    if not isinstance(raw, list):
        return []
    normalized: list[str] = []
    for item in raw:
        value = str(item).strip().lower()
        aliases = {
            "image_url": "image",
            "images": "image",
            "audio_url": "audio",
        }
        value = aliases.get(value, value)
        if value and value not in normalized:
            normalized.append(value)
    return normalized


def _base_model(
    provider_id: str,
    remote_id: str,
    display_name: str,
    description: str,
    chat_endpoint: str,
    api_format: str,
    requires_key: bool,
    key_id: str,
    local: bool,
) -> dict[str, Any]:
    return {
        "providerId": provider_id,
        "remoteId": remote_id,
        "displayName": display_name or remote_id,
        "description": description or "",
        "endpoint": chat_endpoint,
        "apiFormat": api_format,
        "authScheme": "strategy",
        "requiresKey": requires_key,
        "keyId": key_id,
        "local": local,
        "free": local,
        "inputModalities": ["text"],
        "outputModalities": ["text"],
        "capabilities": _capabilities(),
        "contextTokens": 0,
        "maxOutputTokens": 0,
        "pricing": {},
        "expiresAt": "",
        "status": "available",
        "source": "live",
    }


def _normalize_openrouter(
    payload: Any,
    provider_id: str,
    chat_endpoint: str,
    api_format: str,
    requires_key: bool,
    key_id: str,
    local: bool,
) -> list[dict[str, Any]]:
    rows = payload.get("data", []) if isinstance(payload, dict) else []
    models: list[dict[str, Any]] = []
    for row in rows:
        remote_id = str(row.get("id", "")).strip()
        if not remote_id:
            continue
        item = _base_model(
            provider_id,
            remote_id,
            str(row.get("name") or remote_id),
            str(row.get("description") or ""),
            chat_endpoint,
            api_format,
            requires_key,
            key_id,
            local,
        )
        architecture = row.get("architecture") or {}
        input_modalities = _modalities(
            architecture.get("input_modalities") or architecture.get("modality", "").split("->")[0:1]
        )
        output_modalities = _modalities(architecture.get("output_modalities"))
        if input_modalities:
            item["inputModalities"] = input_modalities
        if output_modalities:
            item["outputModalities"] = output_modalities
        supported_parameters = {
            str(value).lower() for value in (row.get("supported_parameters") or [])
        }
        input_set = set(item["inputModalities"])
        capabilities = _capabilities(
            vision=SUPPORTED if "image" in input_set else UNSUPPORTED,
            audioInput=SUPPORTED if "audio" in input_set else UNSUPPORTED,
            toolCalling=SUPPORTED
            if {"tools", "tool_choice"} & supported_parameters
            else UNKNOWN,
            webSearch=SUPPORTED
            if {"web_search", "web_search_options"} & supported_parameters
            else UNKNOWN,
            structuredOutput=SUPPORTED
            if {"response_format", "structured_outputs"} & supported_parameters
            else UNKNOWN,
            reasoning=SUPPORTED
            if {"reasoning", "include_reasoning"} & supported_parameters
            else UNKNOWN,
        )
        item["capabilities"] = capabilities
        item["contextTokens"] = int(row.get("context_length") or 0)
        top_provider = row.get("top_provider") or {}
        item["maxOutputTokens"] = int(top_provider.get("max_completion_tokens") or 0)
        pricing = row.get("pricing") or {}
        item["pricing"] = pricing
        item["free"] = (
            str(pricing.get("prompt", "")).strip() == "0"
            and str(pricing.get("completion", "")).strip() == "0"
        )
        item["expiresAt"] = str(row.get("expiration_date") or "")
        models.append(item)
    return models


def _normalize_ollama(
    payload: Any,
    provider_id: str,
    chat_endpoint: str,
    api_format: str,
    requires_key: bool,
    key_id: str,
    local: bool,
) -> list[dict[str, Any]]:
    rows = payload.get("models", []) if isinstance(payload, dict) else []
    models: list[dict[str, Any]] = []
    for row in rows:
        remote_id = str(row.get("model") or row.get("name") or "").strip()
        if not remote_id:
            continue
        details = row.get("details") or {}
        parameter_size = str(details.get("parameter_size") or "")
        quantization = str(details.get("quantization_level") or "")
        description_parts = [value for value in (parameter_size, quantization) if value]
        item = _base_model(
            provider_id,
            remote_id,
            remote_id,
            " · ".join(description_parts),
            chat_endpoint,
            api_format,
            requires_key,
            key_id,
            local,
        )
        lowered = remote_id.lower()
        item["capabilities"] = _capabilities(
            vision=SUPPORTED if any(token in lowered for token in ("vision", "-vl", ":vl")) else UNKNOWN,
            toolCalling=UNKNOWN,
            structuredOutput=UNKNOWN,
            reasoning=SUPPORTED if any(token in lowered for token in ("reason", "thinking", "deepseek-r1")) else UNKNOWN,
        )
        item["free"] = True
        item["sizeBytes"] = int(row.get("size") or 0)
        item["parameterSize"] = parameter_size
        item["quantization"] = quantization
        models.append(item)
    return models


def _normalize_gemini(
    payload: Any,
    provider_id: str,
    chat_endpoint: str,
    api_format: str,
    requires_key: bool,
    key_id: str,
    local: bool,
) -> list[dict[str, Any]]:
    rows = payload.get("models", []) if isinstance(payload, dict) else []
    models: list[dict[str, Any]] = []
    for row in rows:
        full_name = str(row.get("name") or "")
        remote_id = full_name.removeprefix("models/").strip()
        methods = {str(value) for value in (row.get("supportedGenerationMethods") or [])}
        if not remote_id or not ({"generateContent", "streamGenerateContent"} & methods):
            continue
        endpoint = chat_endpoint.replace("{model}", remote_id)
        item = _base_model(
            provider_id,
            remote_id,
            str(row.get("displayName") or remote_id),
            str(row.get("description") or ""),
            endpoint,
            api_format,
            requires_key,
            key_id,
            local,
        )
        item["contextTokens"] = int(row.get("inputTokenLimit") or 0)
        item["maxOutputTokens"] = int(row.get("outputTokenLimit") or 0)
        item["capabilities"] = _capabilities(
            toolCalling=SUPPORTED,
            webSearch=SUPPORTED,
            structuredOutput=SUPPORTED,
            reasoning=SUPPORTED if any(token in remote_id.lower() for token in ("2.5", "3", "thinking")) else UNKNOWN,
        )
        models.append(item)
    return models


def _friendly_model_name(remote_id: str) -> str:
    words = remote_id.replace("/", " ").replace("-", " ").split()
    acronyms = {"gpt", "glm", "kimi", "qwen", "mimo", "hy", "ai"}
    return " ".join(word.upper() if word.lower() in acronyms else word.capitalize() for word in words)


def _normalize_opencode(
    payload: Any,
    provider_id: str,
    chat_endpoint: str,
    api_format: str,
    requires_key: bool,
    key_id: str,
    local: bool,
) -> list[dict[str, Any]]:
    rows = payload.get("data", []) if isinstance(payload, dict) else []
    is_go = provider_id == "opencode-go"
    base = "https://opencode.ai/zen/go/v1" if is_go else "https://opencode.ai/zen/v1"
    models: list[dict[str, Any]] = []

    for row in rows:
        remote_id = str(row.get("id") if isinstance(row, dict) else row or "").strip()
        if not remote_id:
            continue
        lowered = remote_id.lower()

        if is_go:
            # OpenCode Go publishes two protocol families. MiniMax and Qwen
            # use the Messages shape; the remaining catalog is OpenAI chat.
            if lowered.startswith(("minimax-", "qwen")):
                endpoint = f"{base}/messages"
                resolved_format = "anthropic"
            else:
                endpoint = f"{base}/chat/completions"
                resolved_format = "openai"
        else:
            # Zen routes and authentication both follow the model family.
            if lowered.startswith("gpt-"):
                endpoint = f"{base}/responses"
                resolved_format = "openai-response"
            elif lowered.startswith(("claude-", "qwen")):
                endpoint = f"{base}/messages"
                resolved_format = "anthropic"
            elif lowered.startswith("gemini-"):
                endpoint = f"{base}/models/{remote_id}:streamGenerateContent"
                resolved_format = "gemini"
            else:
                endpoint = f"{base}/chat/completions"
                resolved_format = "openai"

        item = _base_model(
            provider_id,
            remote_id,
            _friendly_model_name(remote_id),
            "",
            endpoint,
            resolved_format,
            requires_key,
            key_id,
            local,
        )
        if resolved_format == "anthropic":
            item["authScheme"] = "anthropic"
        elif resolved_format == "gemini":
            item["authScheme"] = "gemini-header"
        else:
            item["authScheme"] = "bearer"
        item["free"] = (not is_go) and lowered.endswith("-free")
        item["capabilities"] = _capabilities(
            toolCalling=SUPPORTED,
            reasoning=SUPPORTED if any(token in lowered for token in ("gpt-5", "claude-", "deepseek", "glm-5", "kimi-")) else UNKNOWN,
            structuredOutput=SUPPORTED if resolved_format in ("openai", "openai-response") else UNKNOWN,
        )
        models.append(item)
    return models


def _normalize_generic(
    payload: Any,
    provider_id: str,
    chat_endpoint: str,
    api_format: str,
    requires_key: bool,
    key_id: str,
    local: bool,
) -> list[dict[str, Any]]:
    if isinstance(payload, dict):
        rows = payload.get("data") or payload.get("models") or []
    elif isinstance(payload, list):
        rows = payload
    else:
        rows = []
    models: list[dict[str, Any]] = []
    for row in rows:
        if isinstance(row, str):
            remote_id = row
            display_name = row
            description = ""
        elif isinstance(row, dict):
            remote_id = str(row.get("id") or row.get("name") or row.get("model") or "")
            display_name = str(row.get("display_name") or row.get("name") or remote_id)
            description = str(row.get("description") or "")
        else:
            continue
        remote_id = remote_id.strip()
        if not remote_id:
            continue
        item = _base_model(
            provider_id,
            remote_id,
            display_name,
            description,
            chat_endpoint,
            api_format,
            requires_key,
            key_id,
            local,
        )
        if isinstance(row, dict):
            item["contextTokens"] = int(
                row.get("context_length") or row.get("max_context_length") or 0
            )
            capabilities = row.get("capabilities") or {}
            if isinstance(capabilities, dict):
                item["capabilities"] = _capabilities(
                    vision=SUPPORTED if capabilities.get("vision") else UNKNOWN,
                    toolCalling=SUPPORTED if capabilities.get("function_calling") else UNKNOWN,
                    structuredOutput=SUPPORTED if capabilities.get("json_schema") else UNKNOWN,
                )
        models.append(item)
    return models


def _headers(kind: str, key: str) -> dict[str, str]:
    headers = {"Accept": "application/json", "User-Agent": "iNiR/AI-Catalog"}
    if not key:
        return headers
    if kind == "anthropic":
        headers["x-api-key"] = key
        headers["anthropic-version"] = "2023-06-01"
    elif kind == "gemini":
        headers["x-goog-api-key"] = key
    else:
        headers["Authorization"] = f"Bearer {key}"
    return headers


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider-id", required=True)
    parser.add_argument("--kind", required=True)
    parser.add_argument("--models-url", required=True)
    parser.add_argument("--chat-endpoint", required=True)
    parser.add_argument("--api-format", default="openai")
    parser.add_argument("--key-id", default="")
    parser.add_argument("--requires-key", action="store_true")
    parser.add_argument("--public-catalog", action="store_true")
    parser.add_argument("--auth-scheme", default="strategy")
    parser.add_argument("--local", action="store_true")
    parser.add_argument("--timeout", type=float, default=8.0)
    args = parser.parse_args()

    key = os.environ.get("INIR_AI_PROVIDER_KEY", "")
    result: dict[str, Any] = {
        "providerId": args.provider_id,
        "ok": False,
        "models": [],
        "error": "",
        "fetchedAt": int(time.time()),
    }

    # Public catalogs are browseable before authentication. Generation remains
    # locked until the key exists; the QML catalog exposes that distinction.
    if args.requires_key and not key and not args.public_catalog:
        result["error"] = "missing-key"
        print(json.dumps(result, separators=(",", ":")))
        return 0

    url = args.models_url
    if args.kind == "gemini" and key and "key=" not in url:
        delimiter = "&" if "?" in url else "?"
        url = f"{url}{delimiter}key={urllib.parse.quote(key)}"

    try:
        payload = _request_json(url, _headers(args.kind, key), args.timeout)
        normalizer = {
            "openrouter": _normalize_openrouter,
            "ollama": _normalize_ollama,
            "gemini": _normalize_gemini,
            "opencode-zen": _normalize_opencode,
            "opencode-go": _normalize_opencode,
        }.get(args.kind, _normalize_generic)
        models = normalizer(
            payload,
            args.provider_id,
            args.chat_endpoint,
            args.api_format,
            args.requires_key,
            args.key_id,
            args.local,
        )
        for model in models:
            if model.get("authScheme") in (None, "", "strategy"):
                model["authScheme"] = args.auth_scheme
        result["ok"] = True
        result["models"] = models
    except urllib.error.HTTPError as error:
        result["error"] = f"http-{error.code}"
    except urllib.error.URLError as error:
        result["error"] = f"network-{getattr(error, 'reason', 'unavailable')}"
    except (json.JSONDecodeError, TypeError, ValueError) as error:
        result["error"] = f"invalid-response-{error}"
    except Exception as error:  # Defensive boundary for provider-specific payloads.
        result["error"] = f"unexpected-{type(error).__name__}-{error}"

    print(json.dumps(result, separators=(",", ":"), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
