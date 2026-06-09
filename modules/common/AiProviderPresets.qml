pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

/**
 * Curated, one-click AI provider presets for the sidebar assistant.
 *
 * Each preset pre-fills the "Add Provider" form (or registers directly) with a
 * known-good OpenAI-compatible endpoint so users don't have to hunt for base
 * URLs. Endpoints verified June 2026. "Free" presets still usually need a free
 * account/key — that's stated in each description, not hidden.
 */
Singleton {
    id: root

    // Each preset:
    //  id, name, icon, endpoint, model (default), api_format,
    //  requiresKey, keyId, keyGetLink, description, free (bool), local (bool),
    //  dynamic (optional: "openrouter-free" to fetch the live free-model list).
    readonly property var presets: [
        {
            "id": "ollama",
            "name": "Ollama (local)",
            "icon": "ollama-symbolic",
            "endpoint": "http://127.0.0.1:11434/v1/chat/completions",
            "model": "llama3.2",
            "api_format": "openai",
            "requiresKey": false,
            "keyId": "ollama",
            "keyGetLink": "https://ollama.com/download",
            "description": Translation.tr("Local models via Ollama. Installed models are also auto-detected."),
            "free": true,
            "local": true,
        },
        {
            "id": "openrouter-free",
            "name": "OpenRouter (free models)",
            "icon": "spark-symbolic",
            "endpoint": "https://openrouter.ai/api/v1/chat/completions",
            "model": "deepseek/deepseek-r1:free",
            "api_format": "openai",
            "requiresKey": true,
            "keyId": "openrouter",
            "keyGetLink": "https://openrouter.ai/settings/keys",
            "description": Translation.tr("Free-tier models from many providers. Needs a free OpenRouter key. Adds all free models at once."),
            "free": true,
            "local": false,
            "dynamic": "openrouter-free",
        },
        {
            "id": "opencode-zen",
            "name": "OpenCode Zen",
            "icon": "openai-symbolic",
            "endpoint": "https://opencode.ai/zen/v1/chat/completions",
            "model": "opencode/grok-code",
            "api_format": "openai",
            "requiresKey": true,
            "keyId": "opencode-zen",
            "keyGetLink": "https://opencode.ai/auth",
            "description": Translation.tr("Curated coding models, some free for a period. Needs an OpenCode key. Privacy: free models may use your data."),
            "free": true,
            "local": false,
        },
        {
            "id": "groq",
            "name": "Groq (fast & free tier)",
            "icon": "spark-symbolic",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "llama-3.3-70b-versatile",
            "api_format": "openai",
            "requiresKey": true,
            "keyId": "groq",
            "keyGetLink": "https://console.groq.com/keys",
            "description": Translation.tr("Very fast inference with a generous free tier. Needs a free Groq key."),
            "free": true,
            "local": false,
        },
        {
            "id": "google-gemini",
            "name": "Google Gemini (free tier)",
            "icon": "google-gemini-symbolic",
            "endpoint": "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
            "model": "gemini-2.0-flash",
            "api_format": "openai",
            "requiresKey": true,
            "keyId": "gemini",
            "keyGetLink": "https://aistudio.google.com/apikey",
            "description": Translation.tr("Gemini Flash has a free tier. Needs a Google AI Studio key."),
            "free": true,
            "local": false,
        },
        {
            "id": "mistral",
            "name": "Mistral (free tier)",
            "icon": "mistral-symbolic",
            "endpoint": "https://api.mistral.ai/v1/chat/completions",
            "model": "mistral-small-latest",
            "api_format": "openai",
            "requiresKey": true,
            "keyId": "mistral",
            "keyGetLink": "https://console.mistral.ai/api-keys",
            "description": Translation.tr("Mistral offers a free experimentation tier. Needs a Mistral key."),
            "free": true,
            "local": false,
        },
        {
            "id": "cerebras",
            "name": "Cerebras (free tier)",
            "icon": "spark-symbolic",
            "endpoint": "https://api.cerebras.ai/v1/chat/completions",
            "model": "llama-3.3-70b",
            "api_format": "openai",
            "requiresKey": true,
            "keyId": "cerebras",
            "keyGetLink": "https://cloud.cerebras.ai",
            "description": Translation.tr("Extremely fast inference, free tier available. Needs a Cerebras key."),
            "free": true,
            "local": false,
        },
    ]

    function byId(id) {
        return root.presets.find(p => p.id === id) ?? null;
    }

    // Build an ai.extraModels entry from a preset (without the API key, which is
    // stored separately in the keyring). Mirrors the shape Ai.qml expects.
    function toModelEntry(preset) {
        return {
            "api_format": preset.api_format ?? "openai",
            "name": preset.name,
            "model": preset.model,
            "endpoint": preset.endpoint,
            "description": preset.description ?? "",
            "icon": preset.icon ?? "neurology",
            "requires_key": !!preset.requiresKey,
            "key_id": preset.keyId ?? "",
            "key_get_link": preset.keyGetLink ?? "",
        };
    }
}
