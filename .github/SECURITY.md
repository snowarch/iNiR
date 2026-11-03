# Security Policy

## Supported Versions

Only the latest release on the `main` branch receives security updates.

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public issue.**
2. Use [GitHub's private vulnerability reporting](https://github.com/snowarch/inir/security/advisories/new).
3. Alternatively, reach out via the [Discord server](https://discord.gg/pAPTfAhZUJ) (DM a maintainer).

You should receive a response within 72 hours. If the vulnerability is confirmed, a fix will be prioritized and released as soon as practical.

## Scope

iNiR is a desktop shell that runs with user-level permissions. Security concerns include:

- **Config injection** — malicious config.json values that execute arbitrary commands
- **Script injection** — untrusted input reaching shell scripts without sanitization
- **IPC abuse** — external processes calling IPC handlers with crafted arguments
- **Credential exposure** — API keys (Gemini, OpenRouter, etc.) leaking through logs or IPC

Out of scope: compositor vulnerabilities (Niri/Hyprland), Qt/Quickshell framework bugs, and system-level privilege escalation (iNiR never runs as root).
