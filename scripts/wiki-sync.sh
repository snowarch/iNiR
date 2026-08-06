#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root/docs"
wiki_url="https://github.com/snowarch/inir.wiki.git"

usage() {
    cat <<'EOF'
Usage:
  scripts/wiki-sync.sh export <wiki-checkout>
  scripts/wiki-sync.sh check
  scripts/wiki-sync.sh clone [directory]

export  Copy the current docs into an existing GitHub Wiki checkout.
check   Compare the public Wiki with the current docs. Requires network access.
clone   Clone the public Wiki for inspection. It does not publish anything.

Publishing stays manual. Review the Wiki checkout, then commit and push it yourself.
EOF
}

copy_docs() {
    local target=$1
    [[ -d "$target/.git" ]] || {
        printf 'Not a Git checkout: %s\n' "$target" >&2
        exit 2
    }

    find "$target" -maxdepth 1 -type f -name '*.md' -delete
    while IFS= read -r file; do
        name="$(basename "$file")"
        [[ "$name" == "index.md" ]] && name="Home.md"
        cp "$file" "$target/$name"
    done < <(find "$source_dir" -maxdepth 1 -type f -name '*.md' | sort)
}

command=${1:-}
case "$command" in
    export)
        [[ $# -eq 2 ]] || { usage; exit 2; }
        copy_docs "$2"
        ;;
    check)
        [[ $# -eq 1 ]] || { usage; exit 2; }
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT
        git clone --quiet "$wiki_url" "$tmp/wiki"
        copy_docs "$tmp/wiki"
        git -C "$tmp/wiki" diff --no-ext-diff --exit-code -- .
        ;;
    clone)
        target=${2:-wiki}
        git clone "$wiki_url" "$target"
        ;;
    *)
        usage
        exit 2
        ;;
esac
