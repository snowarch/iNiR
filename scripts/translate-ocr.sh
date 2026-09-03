#!/usr/bin/env bash
set -euo pipefail

target=${1:-auto}
source_lang=${2:-auto}
shift $(( $# >= 2 ? 2 : $# ))

if [[ "$target" == "auto" || -z "$target" ]]; then
  locale=${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}
  case "$locale" in
    es*|ES*) target=es ;;
    *) target=en ;;
  esac
fi

if (($# > 0)); then
  text="$*"
else
  text="$(cat)"
fi
text="${text//$'\r'/}"
[[ -n "${text//[[:space:]]/}" ]] || exit 0

trans_bin="$(command -v trans 2>/dev/null || true)"
if [[ -z "$trans_bin" ]]; then
  printf 'translate-shell is not installed\n' >&2
  exit 127
fi

exec "$trans_bin" -brief -no-ansi -no-bidi -source "$source_lang" -target "$target" "$text"
