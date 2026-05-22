#!/usr/bin/env bash
# scripts/setup/_scan.sh
# Emits a JSON array of {slug,name,description,icon,keywords} for every
# scripts/setup/*.sh whose basename does not start with `_`.
#
# Read by services/GlobalActions.qml at startup and on every folder mutation
# of scripts/setup/. Also runnable by hand for debugging:
#     bash scripts/setup/_scan.sh | jq .
shopt -s nullglob
dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
sep=""
printf '['
for f in "$dir"/*.sh; do
    base=${f##*/}; base=${base%.sh}
    case "$base" in _*) continue ;; esac
    printf '%s' "$sep"
    awk -v slug="$base" '
        function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
        /^# @meta name:/        { sub(/^# @meta name:[[:space:]]*/, "");        n=$0 }
        /^# @meta description:/ { sub(/^# @meta description:[[:space:]]*/, ""); d=$0 }
        /^# @meta icon:/        { sub(/^# @meta icon:[[:space:]]*/, "");        i=$0 }
        /^# @meta keywords:/    { sub(/^# @meta keywords:[[:space:]]*/, "");    k=$0 }
        NR >= 60 { exit }
        END { printf "{\"slug\":\"%s\",\"name\":\"%s\",\"description\":\"%s\",\"icon\":\"%s\",\"keywords\":\"%s\"}",
              esc(slug), esc(n), esc(d), esc(i), esc(k) }
    ' "$f"
    sep=","
done
printf ']\n'
