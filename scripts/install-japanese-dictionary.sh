#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$SCRIPT_DIR/japanese-dictionary.py"
JITENDEX_URL="${INIR_JITENDEX_URL:-https://github.com/stephenmk/stephenmk.github.io/releases/latest/download/jitendex-yomitan.zip}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/inir/japanese-dictionary"

mkdir -p "$CACHE_DIR"
tmp="$(mktemp "$CACHE_DIR/jitendex.XXXXXX.zip")"
trap 'rm -f "$tmp"' EXIT

if ! command -v curl >/dev/null 2>&1; then
  printf '{"ok":false,"error":"curl is required to download Jitendex"}\n'
  exit 1
fi

curl --fail --location --silent --show-error \
  --retry 3 --retry-delay 1 --connect-timeout 15 \
  --output "$tmp" "$JITENDEX_URL"

python3 "$BACKEND" import "$tmp"
