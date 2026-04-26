#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/release.sh notes <version> [output-file]
  scripts/release.sh publish <version>

Commands:
  notes    Extract the matching CHANGELOG section and append release footer links.
  publish  Create the GitHub release for an existing local tag v<version>.

EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_clean_version() {
  [[ $# -ge 1 ]] || die "missing version"
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like X.Y.Z"
}

extract_notes() {
  local version="$1"
  awk -v version="$version" '
    $0 ~ ("^## \\[" version "\\] - ") {
      in_section = 1
      next
    }
    in_section {
      if ($0 ~ /^## \[/) exit
      print
    }
  ' CHANGELOG.md | sed '/^$/N;/^\n$/D'
}

write_notes() {
  local version="$1"
  local outfile="$2"
  local notes
  notes="$(extract_notes "$version")"
  [[ -n "$notes" ]] || die "could not find CHANGELOG section for $version"

  cat > "$outfile" <<EOF
$notes

---

Update: https://github.com/snowarch/iNiR?tab=readme-ov-file#update
Fresh install: https://github.com/snowarch/iNiR?tab=readme-ov-file#install
Full changelog: https://github.com/snowarch/iNiR/blob/main/CHANGELOG.md
EOF
}

publish_release() {
  local version="$1"
  local tag="v$version"
  local notes_file
  git rev-parse --verify "$tag" >/dev/null 2>&1 || die "missing local tag $tag"

  notes_file="$(mktemp)"
  write_notes "$version" "$notes_file"

  gh release view "$tag" >/dev/null 2>&1 && die "GitHub release $tag already exists"
  gh release create "$tag" --title "$tag" --notes-file "$notes_file"
  rm -f "$notes_file"
}

main() {
  [[ $# -ge 2 ]] || {
    usage
    exit 1
  }

  local cmd="$1"
  local version="$2"
  require_clean_version "$version"

  case "$cmd" in
    notes)
      local outfile="${3:-}"
      if [[ -n "$outfile" ]]; then
        write_notes "$version" "$outfile"
      else
        local tmpfile
        tmpfile="$(mktemp)"
        write_notes "$version" "$tmpfile"
        cat "$tmpfile"
        rm -f "$tmpfile"
      fi
      ;;
    publish)
      publish_release "$version"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
