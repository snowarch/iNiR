#!/usr/bin/env bash
# verify-docs.sh — fail-loud doc/code drift checker. Source of truth is ALWAYS the
# code: every check derives its expected set by scanning the tree, never from a
# hardcoded list (a hardcoded list would drift too). Exit != 0 on any mismatch so
# it can gate pre-commit / CI. Run from repo root: ./scripts/verify-docs.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
fail=0
note() { printf '  - %s\n' "$1"; fail=1; }

# 1. IPC targets: code (services/) vs docs/SERVICES.md — both directions.
real_ipc=$(grep -rl 'IpcHandler' services/ --include='*.qml' 2>/dev/null \
  | xargs grep -hoP 'target:\s*"\K[^"]+' 2>/dev/null | sort -u)
doc_ipc=$(grep -oP 'IPC target: `\K[^`]+' docs/SERVICES.md 2>/dev/null | sort -u)
echo "[IPC] services/ vs docs/SERVICES.md"
while read -r t; do [ -n "$t" ] && ! grep -qxF "$t" <<<"$doc_ipc" \
  && note "IPC '$t' exists in code but is NOT documented in docs/SERVICES.md"; done <<<"$real_ipc"
while read -r t; do [ -n "$t" ] && ! grep -qxF "$t" <<<"$real_ipc" \
  && note "IPC '$t' documented in docs/SERVICES.md but NO service exposes it"; done <<<"$doc_ipc"

# 2. docs/IPC.md ### headers must each be a real target somewhere in the tree.
#    (colorpicker etc. are standalone CLI commands documented under their own
#    heading, so only check headers that sit above the 'Standalone Commands' line.)
all_ipc=$(grep -rhoP 'target:\s*"\K[^"]+' . --include='*.qml' 2>/dev/null | sort -u)
standalone_line=$(grep -n 'Standalone Commands' docs/IPC.md | head -1 | cut -d: -f1)
: "${standalone_line:=999999}"
echo "[IPC] docs/IPC.md headers vs code"
while IFS=: read -r ln t; do
  [ -z "$t" ] && continue
  [ "$ln" -ge "$standalone_line" ] && continue   # below 'Standalone Commands' = CLI, not IPC
  grep -qxF "$t" <<<"$all_ipc" || note "docs/IPC.md documents '### $t' but no IpcHandler target '$t' exists"
done < <(grep -noP '^### \K[a-zA-Z]+' docs/IPC.md 2>/dev/null)

# 3. Backtick-quoted .qml references in docs/*.md must resolve to a real file
#    (docs cite by basename, so match the file ANYWHERE in the tree).
echo "[paths] .qml references in docs/*.md"
grep -rhoP '`\K[a-zA-Z0-9_./-]+\.qml(?=`)' docs/*.md 2>/dev/null | sort -u \
  | while read -r p; do
      b=$(basename "$p")
      find . -name "$b" -not -path './.git/*' -print -quit 2>/dev/null | grep -q . \
        || note "docs reference '$p' but no file named '$b' exists"
    done

# 4. (local, optional) nested AGENTS.md are gitignored — only checked if present.
#    Same basename match; these cite components by name.
if find modules services -name AGENTS.md -print -quit 2>/dev/null | grep -q .; then
  echo "[local] nested AGENTS.md .qml references"
  grep -rhoP '`\K[a-zA-Z0-9_./-]+\.qml(?=`)' $(find modules services -name AGENTS.md) 2>/dev/null \
    | sort -u | while read -r p; do
        b=$(basename "$p")
        find . -name "$b" -not -path './.git/*' -print -quit 2>/dev/null | grep -q . \
          || note "a nested AGENTS.md references '$p' but no file named '$b' exists"
      done
fi

# 5. Runtime locales must expose the same keys, placeholders and markup as
#    English. The localization tool owns this contract so review batches and
#    repository verification cannot drift apart.
echo "[i18n] runtime locale structure"
if command -v python3 >/dev/null 2>&1 && [ -f translations/tools/l10n.py ]; then
  python3 translations/tools/l10n.py audit-guides \
    || note "supported runtime locales and locale review guides differ"
  python3 translations/tools/l10n.py audit-source \
    || note "runtime source strings are missing from translations/en_US.json"
  python3 translations/tools/l10n.py audit-all \
    || note "runtime locale validation failed"
else
  note "python3 and translations/tools/l10n.py are required for locale validation"
fi

# 6. Generated IPC CLI registry must be in sync with docs/IPC.md + QML targets.
#    A stale scripts/lib/ipc-registry.sh breaks the `inir <target> <fn>` shorthand
#    even though the IPC itself works — the bug that hid the dashboard target.
if command -v python3 >/dev/null 2>&1 && [ -f scripts/lib/generate-ipc-registry.py ]; then
  echo "[IPC] generated CLI registry freshness"
  python3 scripts/lib/generate-ipc-registry.py --check >/dev/null 2>&1 \
    || note "scripts/lib/ipc-registry.sh is stale — run: python3 scripts/lib/generate-ipc-registry.py"
fi

[ "$fail" -eq 0 ] && echo "OK - docs and translations match code." || echo "DRIFT FOUND (see above)."
exit "$fail"
