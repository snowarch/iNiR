#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/release.sh notes <version> [output-file]
  scripts/release.sh publish <version>

Commands:
  notes    Extract the matching CHANGELOG section and append release footer links.
  publish  Create the GitHub release for an existing local tag v<version>, attach the
           README hero image, and sync the Wiki.

EOF
}

readme_release_image() {
  local src
  src="$(sed -n 's/.*<img src="\([^"]*\)".*/\1/p' README.md | head -n1)"
  [[ -n "$src" ]] || die "README does not contain a hero image"
  if [[ "$src" == http://* || "$src" == https://* ]]; then
    die "README hero must be a repository-local file for release publishing"
  fi
  [[ -f "$src" ]] || die "README hero image does not exist: $src"
  printf '%s\n' "$src"
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
  local image_path="${3:-}"
  local notes
  notes="$(extract_notes "$version")"
  [[ -n "$notes" ]] || die "could not find CHANGELOG section for $version"

  if [[ -n "$image_path" ]]; then
    local tag="v$version"
    local asset_name
    local image_url
    asset_name="$(basename "$image_path")"
    image_url="https://github.com/snowarch/iNiR/releases/download/${tag}/${asset_name}"
    printf '%s\n' "$notes" | awk -v image_url="$image_url" -v version="$version" '
      !inserted && /^### / {
        print "<p align=\"center\">"
        print "  <img src=\"" image_url "\" alt=\"iNiR " version " desktop\" width=\"100%\">"
        print "</p>"
        print ""
        inserted = 1
      }
      { print }
      END {
        if (!inserted) {
          print ""
          print "<p align=\"center\">"
          print "  <img src=\"" image_url "\" alt=\"iNiR " version " desktop\" width=\"100%\">"
          print "</p>"
        }
      }
    ' > "$outfile"
  else
    printf '%s\n' "$notes" > "$outfile"
  fi

  cat >> "$outfile" <<EOF
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
  local image_path
  git rev-parse --verify "$tag" >/dev/null 2>&1 || die "missing local tag $tag"

  image_path="$(readme_release_image)"
  notes_file="$(mktemp)"
  write_notes "$version" "$notes_file" "$image_path"

  gh release view "$tag" >/dev/null 2>&1 && die "GitHub release $tag already exists"
  "$script_dir/wiki-sync.sh" publish "docs: sync wiki for $tag"
  gh release create "$tag" "$image_path" --title "$tag" --notes-file "$notes_file"
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
