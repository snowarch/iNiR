#!/usr/bin/env bash
# Release flow for iNiR. People update with `git pull --ff-only` on their branch,
# so a release reaches them the moment main moves; the tag and the GitHub release
# only announce it. Everything here keeps main fast-forward only.
set -euo pipefail
trap 'printf "error: release.sh stopped at line %s\n" "$LINENO" >&2' ERR

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

remote="origin"
github_repo="snowarch/iNiR"
changelog="CHANGELOG.md"

usage() {
  cat <<'EOF'
Usage:
  scripts/release.sh prepare <version>
  scripts/release.sh check <version> [--quick]
  scripts/release.sh publish <version> [title]
  scripts/release.sh notes <version> [output-file]

prepare  Turn [Unreleased] into the dated <version> section, write <version> into every
         file that carries it and commit "chore(release): prepare <version>". Safe to
         run again after fixing what check reports.
check    Everything publish needs, without changing anything: versions, changelog,
         branches, tag, hero image, and make test-local (skipped with --quick;
         --content checks only the files).
publish  Run check (its tests only if check has not passed on this commit), move
         main forward to this commit, tag it, push, create the GitHub release
         and sync the Wiki. Each step is skipped when already done, so a
         publish that stopped halfway can be run again. The title defaults to the
         tag. Issues the notes list as fixed are closed with a pointer to it.
notes    Print the release notes publish would use.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

say() {
  printf '%s\n' "$*"
}

require_version() {
  [[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like X.Y.Z"
}

# Files that carry the version, as "path|pattern that must hold it".
version_carriers() {
  local v="$1"
  local ve="${v//./\\.}"
  printf '%s\n' \
    "VERSION|^${ve}\$" \
    "distro/arch/inir-meta/PKGBUILD|^pkgver=${ve}\$" \
    "distro/arch/inir-meta/.SRCINFO|^[[:space:]]*pkgver = ${ve}\$" \
    "distro/arch/inir-shell/PKGBUILD|^pkgver=${ve}\$" \
    "distro/arch/inir-shell/.SRCINFO|^[[:space:]]*pkgver = ${ve}\$" \
    "sdata/dist-arch/inir-deps/PKGBUILD|^pkgver=${ve}\$" \
    "sdata/dist-arch/install-deps.sh|echo '${ve}'" \
    "scripts/lyrics/lyrics.py|iNiR/${ve} \\(" \
    "ARCHITECTURE.md|^\\*\\*Version\\*\\*: ${ve} " \
    "README.md|badge/version-${ve}-blue"
  local readme
  for readme in docs/readme/README.*.md; do
    printf '%s\n' "${readme}|badge/version-${ve}-blue"
  done
}

write_version() {
  local v="$1"
  printf '%s\n' "$v" > VERSION
  local pkgbuild
  for pkgbuild in distro/arch/inir-meta/PKGBUILD distro/arch/inir-shell/PKGBUILD sdata/dist-arch/inir-deps/PKGBUILD; do
    if ! grep -q "^pkgver=${v}\$" "$pkgbuild"; then
      sed -i -e "s/^pkgver=.*/pkgver=${v}/" -e "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild"
    fi
  done
  sed -i "s/echo '[0-9]*\.[0-9]*\.[0-9]*'/echo '${v}'/" sdata/dist-arch/install-deps.sh
  sed -i "s#iNiR/[0-9]*\.[0-9]*\.[0-9]* (#iNiR/${v} (#" scripts/lyrics/lyrics.py
  sed -i "s/^\*\*Version\*\*: [0-9]*\.[0-9]*\.[0-9]* /**Version**: ${v} /" ARCHITECTURE.md
  sed -i "s/badge\/version-[0-9]*\.[0-9]*\.[0-9]*-blue/badge\/version-${v}-blue/" README.md docs/readme/README.*.md
  local dir
  for dir in distro/arch/inir-meta distro/arch/inir-shell; do
    write_srcinfo "$dir" "$v"
  done
}

write_srcinfo() {
  local dir="$1" v="$2"
  if command -v makepkg >/dev/null 2>&1; then
    (cd "$dir" && makepkg --printsrcinfo > .SRCINFO)
  else
    sed -i -e "s/^\([[:space:]]*pkgver = \).*/\1${v}/" -e "s/^\([[:space:]]*pkgrel = \).*/\11/" \
      -e "s/inir-[0-9]*\.[0-9]*\.[0-9]*\.tar\.gz::\(.*\)\/v[0-9]*\.[0-9]*\.[0-9]*\.tar\.gz/inir-${v}.tar.gz::\1\/v${v}.tar.gz/" \
      "$dir/.SRCINFO"
  fi
}

# iRiS keeps its own version (modules/iris/VERSION); every section opens with it.
iris_version() {
  tr -d '[:space:]' < modules/iris/VERSION 2>/dev/null
}

# The dated section for <version>, without its heading.
section_body() {
  awk -v v="$1" '
    index($0, "## [" v "] - ") == 1 { on = 1; next }
    on && /^## \[/ { exit }
    on { print }
  ' "$changelog"
}

unreleased_body() {
  awk '
    $0 == "## [Unreleased]" { on = 1; next }
    on && /^## \[/ { exit }
    on { print }
  ' "$changelog"
}

# Everything from the first released heading down, as of a given revision.
released_history() {
  local rev="$1" from="$2"
  if [[ "$rev" == "worktree" ]]; then cat "$changelog"; else git show "${rev}:${changelog}" 2>/dev/null; fi \
    | awk -v h="## [${from}] - " 'index($0, h) == 1 { on = 1 } on'
}

cut_changelog_section() {
  local v="$1" today
  today="$(date +%F)"
  if grep -q "^## \[${v}\] - " "$changelog"; then
    return
  fi
  grep -q '^## \[Unreleased\]$' "$changelog" || die "$changelog has no ## [Unreleased] heading"
  [[ -n "$(unreleased_body | tr -d '[:space:]')" ]] || die "[Unreleased] is empty: write the changes first"
  awk -v v="$v" -v d="$today" -v iris="$(iris_version)" '
    !done && $0 == "## [Unreleased]" { print "## [" v "] - " d; print ""; if (iris != "") { print "**iRiS " iris "**"; print "" } done = 1; skip = 1; next }
    skip && /^$/ { skip = 0; next }
    { skip = 0; print }
  ' "$changelog" > "$changelog.tmp"
  mv "$changelog.tmp" "$changelog"
}

previous_tag() {
  git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' HEAD 2>/dev/null || true
}

# Screenshots for the release body live in docs/images/releases/<version>/ (docs/
# never ships in the runtime payload): NN-name.webp files and captions.tsv with
# "file<TAB>caption" per line, shown two per row under the hero image.
media_dir() {
  printf 'docs/images/releases/%s' "$1"
}

gallery_files() {
  local dir
  dir="$(media_dir "$1")"
  [[ -f "$dir/captions.tsv" ]] || return 0
  awk -F '\t' -v d="$dir" 'NF >= 2 { print d "/" $1 }' "$dir/captions.tsv"
}

readme_release_image() {
  local src
  src="$(sed -n 's/.*<img src="\([^"]*\)".*/\1/p' README.md | head -n1)"
  [[ -n "$src" ]] || return 1
  [[ "$src" != http://* && "$src" != https://* && -f "$src" ]] || return 1
  printf '%s\n' "$src"
}

# ---------------------------------------------------------------------------- check

failures=()
warnings=()
fail() { failures+=("$*"); }
warn() { warnings+=("$*"); }

check_versions() {
  local v="$1" entry path pattern
  while IFS= read -r entry; do
    path="${entry%%|*}"
    pattern="${entry#*|}"
    [[ -f "$path" ]] || { fail "$path is missing"; continue; }
    grep -Eq "$pattern" "$path" || fail "$path does not say $v"
  done < <(version_carriers "$v")
  if command -v makepkg >/dev/null 2>&1; then
    local dir
    for dir in distro/arch/inir-meta distro/arch/inir-shell; do
      diff -q <(cd "$dir" && makepkg --printsrcinfo 2>/dev/null) "$dir/.SRCINFO" >/dev/null \
        || fail "$dir/.SRCINFO is stale (makepkg --printsrcinfo)"
    done
  fi
}

# Every release reads like v2.28.0: one intro line, then Added, Changed, Fixed,
# Issues / PRs and Contributors in that order, one line per entry. GitHub keeps
# every newline in a release body, so a wrapped line shows up broken (v2.31.0).
release_groups=("Added" "Changed" "Fixed" "Issues / PRs" "Contributors")

check_shape() {
  local v="$1" body="$2"
  local intro line heading prev="" section="" rank=-1 found i n=0
  local iris tag
  iris="$(iris_version)"
  tag="$(awk 'NF { print; exit }' <<<"$body")"
  if [[ -n "$iris" ]]; then
    [[ "$tag" == "**iRiS $iris**" ]] || fail "the $v notes must open with \"**iRiS $iris**\" (modules/iris/VERSION)"
    intro="$(awk 'NF { n++ } NF && n == 2 { print; exit }' <<<"$body")"
  else
    intro="$tag"
  fi
  [[ -n "$intro" && "$intro" != "#"* && "$intro" != "- "* ]] || fail "the $v notes must open with one intro line"
  while IFS= read -r line; do
    n=$((n + 1))
    if [[ -n "$prev" && "$prev" != "### "* && -n "$line" && "$line" != "- "* && "$line" != "### "* ]]; then
      fail "line $n of the $v notes continues the line above: keep each paragraph and entry on one line"
    fi
    if [[ "$line" == "### "* ]]; then
      heading="${line:4}"
      found=-1
      for i in "${!release_groups[@]}"; do
        [[ "${release_groups[$i]}" == "$heading" ]] && found=$i
      done
      if (( found < 0 )); then
        fail "the $v notes have a group \"$heading\"; use ${release_groups[*]}"
      elif (( found <= rank )); then
        fail "the $v notes put \"$heading\" out of order; use ${release_groups[*]}"
      else
        rank=$found
      fi
      section="$heading"
    elif [[ "$section" == "Added" && "$line" == "- "* && "$line" != "- **"*"**: "* ]]; then
      fail "line $n: Added entries read \"- **Name**: what it does\""
    fi
    prev="$line"
  done <<<"$body"
  (( rank >= 0 )) || fail "the $v notes have no Added, Changed or Fixed group"
}

check_changelog() {
  local v="$1" body prev prev_v
  body="$(section_body "$v")"
  if [[ -z "$(tr -d '[:space:]' <<<"$body")" ]]; then
    fail "$changelog has no dated section for $v (run prepare)"
    return
  fi
  local date
  date="$(sed -n "s/^## \[${v//./\\.}\] - \([0-9-]*\)$/\1/p" "$changelog")"
  [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "the $v heading needs a YYYY-MM-DD date"
  [[ -z "$(unreleased_body | grep -E '^[-*] ' || true)" ]] || fail "[Unreleased] still has entries above $v"
  grep -q $'—' <<<"$body" && fail "the $v notes use em dashes"
  check_shape "$v" "$body"

  prev="$(previous_tag)"
  if [[ -n "$prev" && "$prev" != "v$v" ]]; then
    prev_v="${prev#v}"
    if ! diff -q <(released_history "$prev" "$prev_v") <(released_history worktree "$prev_v") >/dev/null; then
      fail "sections released up to $prev changed since then (entries for this cycle belong under $v): git diff $prev -- $changelog"
    fi
    # Every issue a commit since the last tag fixes and every PR it merges is named, and whoever opened an issue is thanked.
    local n missing=""
    for n in $( { git log --format=%B "$prev"..HEAD | grep -oiE '(fixes|closes|part of) #[0-9]+' || true
                  git log --format=%s "$prev"..HEAD | grep -oE '\(#[0-9]+\)$' || true; } | grep -oE '[0-9]+' | sort -un); do
      grep -qE "/(issues|pull)/$n\)" <<<"$body" || missing+=" #$n"
    done
    [[ -z "$missing" ]] || fail "the $v notes don't name$missing, which commits since $prev fix or merge"
    local issue author
    for issue in $(fixed_issues "$v"); do
      author="$(gh issue view "$issue" --repo "$github_repo" --json author -q .author.login 2>/dev/null || true)"
      if [[ -z "$author" ]]; then
        warn "could not read who opened #$issue"
      elif [[ "$author" != "${github_repo%%/*}" ]] && ! grep -qF "[@$author]" <<<"$body"; then
        fail "the $v Contributors don't thank @$author, who opened #$issue"
      fi
    done
  fi
}

check_git() {
  local v="$1" tag="v$1" head branch
  head="$(git rev-parse HEAD)"
  branch="$(git symbolic-ref --quiet --short HEAD || true)"
  [[ -n "$branch" ]] || fail "HEAD is detached: publish from a branch"
  [[ -z "$(git status --porcelain --untracked-files=no)" ]] || fail "tracked files have uncommitted changes"
  git fetch --quiet "$remote" main --tags 2>/dev/null || warn "could not fetch $remote; remote checks use what is cached"
  if ! git merge-base --is-ancestor "$remote/main" HEAD; then
    fail "$remote/main is not an ancestor of HEAD: main could not move forward without rewriting history"
  fi
  if git show-ref --verify --quiet "refs/heads/main" && ! git merge-base --is-ancestor main HEAD; then
    fail "local main has commits that are not in HEAD"
  fi
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    [[ "$(git rev-parse "$tag^{commit}")" == "$head" ]] || fail "tag $tag already exists on another commit"
  fi
  local remote_tag
  remote_tag="$(git ls-remote --tags "$remote" "refs/tags/$tag^{}" 2>/dev/null | cut -f1)"
  [[ -z "$remote_tag" ]] && remote_tag="$(git ls-remote --tags "$remote" "refs/tags/$tag" 2>/dev/null | cut -f1)"
  [[ -z "$remote_tag" || "$remote_tag" == "$head" ]] || fail "$remote already has $tag on another commit"
  readme_release_image >/dev/null || fail "README's first image must be a file in the repository (it is the release image)"
}

run_check() {
  local v="$1" quick="${2:-}"
  failures=()
  warnings=()
  [[ "$(cat VERSION)" == "$v" ]] || fail "VERSION says $(cat VERSION), not $v (run prepare)"
  check_versions "$v"
  check_changelog "$v"
  check_links
  check_media "$v"
  [[ "$quick" == "--content" ]] || check_git "$v"
  if [[ -z "$quick" && ${#failures[@]} -eq 0 ]]; then
    say "running make test-local"
    make test-local >/tmp/inir-release-test.log 2>&1 || fail "make test-local failed: /tmp/inir-release-test.log"
  fi
  local w f
  for w in "${warnings[@]}"; do printf 'warning: %s\n' "$w"; done
  for f in "${failures[@]}"; do printf 'fail: %s\n' "$f"; done
  if (( ${#failures[@]} > 0 )); then
    return 1
  fi
  [[ -n "$quick" ]] || printf '%s %s\n' "$(git rev-parse HEAD)" "$v" >"$(git rev-parse --git-path inir-release-tested)"
  say "$v is ready to publish"
}

# ---------------------------------------------------------------------------- notes

# The footer's three links. Update and install go to the Wiki pages that explain
# them (synced from docs/ by publish); the changelog is pinned to the tag, so the
# link keeps showing this release after main moves on.
footer_link() {
  local what="$1" v="$2"
  case "$what" in
    update) printf 'https://github.com/%s/wiki/SETUP#update' "$github_repo" ;;
    install) printf 'https://github.com/%s/wiki/INSTALL' "$github_repo" ;;
    changelog)
      local anchor
      anchor="$(sed -n "s/^## \[${v//./\\.}\] - \([0-9-]*\)$/${v//./}---\1/p" "$changelog")"
      printf 'https://github.com/%s/blob/v%s/CHANGELOG.md#%s' "$github_repo" "$v" "$anchor"
      ;;
  esac
}

check_media() {
  local v="$1" dir file caption count=0 image
  dir="$(media_dir "$v")"
  image="$(readme_release_image || true)"
  if [[ ! -f "$dir/captions.tsv" ]]; then
    warn "no screenshots beside the hero for $v ($dir/captions.tsv)"
    check_private_text "$image"
    return
  fi
  while IFS=$'\t' read -r file caption; do
    [[ -n "$file" ]] || continue
    [[ -f "$dir/$file" ]] || fail "$dir/captions.tsv names $file, which is missing"
    [[ -n "$caption" ]] || fail "$dir/$file has no caption"
    count=$((count + 1))
  done < "$dir/captions.tsv"
  (( count == 1 || count % 2 == 0 )) || warn "$v shows an odd number of screenshots; the gallery reads best in pairs"
  check_private_text "$image" $(gallery_files "$v")
}

# Text that must never reach a public image: the git email, and any mention of AI
# tools (notifications from them do show up in the Control Center).
check_private_text() {
  command -v tesseract >/dev/null 2>&1 || { warn "tesseract is missing: screenshots were not read for private text"; return; }
  local email pattern image tmp text hits
  email="$(git config user.email || true)"
  pattern='claude|anthropic|openai|chatgpt|codex|copilot|gemini cli'
  [[ -n "$email" ]] && pattern="$pattern|${email//./\\.}"
  tmp="$(mktemp -d)"
  for image in "$@"; do
    [[ -f "$image" ]] || continue
    magick "$image" -resize 300% -colorspace Gray -normalize "$tmp/a.png" 2>/dev/null || continue
    magick "$tmp/a.png" -negate "$tmp/b.png"
    text="$(tesseract "$tmp/a.png" - --psm 11 2>/dev/null; tesseract "$tmp/b.png" - --psm 11 2>/dev/null)"
    hits="$(grep -oiE "$pattern" <<<"$text" | sort -uf | tr '\n' ' ' || true)"
    [[ -z "$hits" ]] || fail "$image shows: $hits(retake it without that on screen)"
  done
  rm -rf "$tmp"
}

check_links() {
  grep -qx '## Update' docs/SETUP.md || fail "docs/SETUP.md lost its \"## Update\" heading (the Update link's anchor)"
  [[ -f docs/INSTALL.md ]] || fail "docs/INSTALL.md is missing (the Fresh install link)"
}

write_notes() {
  local v="$1" out="$2" image="${3:-}"
  local notes
  # A wrapped line is joined back onto its entry, in case check was skipped.
  notes="$(section_body "$v" | awk '
    NF && held != "" && held !~ /^### / && $0 !~ /^(- |### |<)/ { sub(/^[[:space:]]+/, ""); held = held " " $0; next }
    { if (started) print held; held = $0; started = 1 }
    END { if (started) print held }
  ' | sed '/^$/N;/^\n$/D' | sed '/./,$!d')"
  [[ -n "$(tr -d '[:space:]' <<<"$notes")" ]] || die "could not find the $changelog section for $v"
  if [[ -n "$image" ]]; then
    local url="https://github.com/${github_repo}/releases/download/v${v}/$(basename "$image")"
    awk -v url="$url" -v v="$v" '
      { print }
      # The hero follows the intro line; the iRiS tag and a note above the intro (a quote) come first.
      NF && $0 !~ /^\*\*iRiS [0-9.]+\*\*$/ && $0 !~ /^> / && !done {
        print ""
        print "<p align=\"center\">"
        print "  <img src=\"" url "\" alt=\"iNiR " v " desktop\" width=\"100%\">"
        print "</p>"
        done = 1
      }
    ' <<<"$notes" > "$out.body"
    local gallery
    gallery="$(gallery_html "$v")"
    if [[ -n "$gallery" ]]; then
      awk -v g="$gallery" '{ print } /^<\/p>$/ && !done { print ""; print g; done = 1 }' "$out.body" > "$out"
    else
      mv "$out.body" "$out"
    fi
    rm -f "$out.body"
  else
    printf '%s\n' "$notes" > "$out"
  fi
  cat >> "$out" <<EOF

---

Update: $(footer_link update "$v")  
Fresh install: $(footer_link install "$v")  
Full changelog: $(footer_link changelog "$v")
EOF
}

# Issue numbers on the "Fixed ..." line of Issues / PRs.
fixed_issues() {
  section_body "$1" | awk '/^### Issues \/ PRs$/ { on = 1; next } on && /^### / { exit } on && /^- Fixed / { print }' \
    | grep -o 'issues/[0-9]*' | cut -d/ -f2 | sort -un
}

gallery_html() {
  local v="$1" dir file caption cell=0 rows=""
  dir="$(media_dir "$v")"
  [[ -f "$dir/captions.tsv" ]] || return 0
  # One screenshot stands under the hero at its full width, not in half a row beside an empty cell.
  if [[ "$(awk -F '\t' 'NF >= 2 && $1 != "" && $2 != ""' "$dir/captions.tsv" | wc -l)" -eq 1 ]]; then
    IFS=$'\t' read -r file caption < <(awk -F '\t' 'NF >= 2 && $1 != "" && $2 != ""' "$dir/captions.tsv")
    printf '<p align="center"><img src="https://github.com/%s/releases/download/v%s/%s" alt="%s" width="100%%"><br><sub>%s</sub></p>' \
      "$github_repo" "$v" "$file" "$caption" "$caption"
    return 0
  fi
  rows="<table>"
  while IFS=$'\t' read -r file caption; do
    [[ -n "$file" && -n "$caption" ]] || continue
    (( cell % 2 == 0 )) && rows+=$'\n'"<tr>"
    rows+=$'\n'"<td width=\"50%\" align=\"center\"><img src=\"https://github.com/${github_repo}/releases/download/v${v}/${file}\" alt=\"${caption}\" width=\"100%\"><br><sub>${caption}</sub></td>"
    cell=$((cell + 1))
    (( cell % 2 == 0 )) && rows+=$'\n'"</tr>"
  done < "$dir/captions.tsv"
  (( cell % 2 == 1 )) && rows+=$'\n'"<td></td></tr>"
  printf '%s\n</table>' "$rows"
}

# ---------------------------------------------------------------------------- commands

cmd_prepare() {
  local v="$1"
  local files=(VERSION modules/iris/VERSION "$changelog" ARCHITECTURE.md README.md docs/readme/README.*.md
    distro/arch/inir-meta distro/arch/inir-shell sdata/dist-arch/inir-deps/PKGBUILD
    sdata/dist-arch/install-deps.sh scripts/lyrics/lyrics.py)
  local excludes=() f
  for f in "${files[@]}"; do excludes+=(":!$f"); done
  [[ -z "$(git status --porcelain --untracked-files=no -- . "${excludes[@]}")" ]] \
    || die "commit or stash your work first (only the changelog and the version files may have edits)"
  cut_changelog_section "$v"
  write_version "$v"
  run_check "$v" --content || {
    say "fix the failures above, then run prepare again"
    exit 1
  }
  git add -- "${files[@]}"
  if git diff --cached --quiet; then
    say "$v was already prepared"
  else
    git commit --quiet -m "chore(release): prepare $v"
    say "committed: $(git log -1 --format='%h %s')"
  fi
  say "next: read 'scripts/release.sh notes $v', then 'scripts/release.sh check $v'"
}

cmd_publish() {
  local v="$1" title="${2:-}"
  local tag="v$v"
  [[ -n "$title" ]] || title="$tag"
  # check already ran the tests on this exact commit (the tree is clean, check_git holds it): skip only them.
  if [[ "$(cat "$(git rev-parse --git-path inir-release-tested)" 2>/dev/null)" == "$(git rev-parse HEAD) $v" ]]; then
    run_check "$v" --quick || die "not publishing"
  else
    run_check "$v" || die "not publishing"
  fi

  local head branch image
  head="$(git rev-parse HEAD)"
  branch="$(git symbolic-ref --short HEAD)"
  image="$(readme_release_image)"

  say ""
  say "About to publish $tag \"$title\" from $branch at $(git log -1 --format='%h %s')."
  say "main moves to this commit, and everyone following main gets it on their next update."
  local fixed
  fixed="$(fixed_issues "$v")"
  [[ -z "$fixed" ]] || say "Issues closed as fixed in $tag: $(tr '\n' ' ' <<<"$fixed")"
  read -r -p "Publish? [y/N] " answer
  [[ "$answer" == [yY] ]] || die "stopped before changing anything"

  # Everything that can fail locally happens before anything leaves this machine.
  if ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    local message="iNiR $v"
    [[ -z "$(iris_version)" ]] || message="$message, iRiS $(iris_version)"
    if [[ "$title" == "$tag" ]]; then
      git tag -a "$tag" -m "$message"
    else
      git tag -a "$tag" -m "$message" -m "$title"
    fi
  fi
  # Skip what the remote already has: a publish after a manual push or a run that stopped halfway goes on.
  if [[ "$(git rev-parse "$remote/$branch" 2>/dev/null)" != "$head" ]]; then
    git push --quiet "$remote" "HEAD:refs/heads/$branch"
  fi
  if [[ "$(git rev-parse "$remote/main" 2>/dev/null)" != "$head" ]]; then
    git push --quiet "$remote" "HEAD:refs/heads/main"
    say "main -> $(git rev-parse --short HEAD)"
  fi
  if [[ "$branch" != "main" ]] && git show-ref --verify --quiet refs/heads/main \
      && ! git worktree list --porcelain | grep -qx 'branch refs/heads/main'; then
    git update-ref refs/heads/main "$head"
  fi

  [[ -n "$(git ls-remote "$remote" "refs/tags/$tag")" ]] || git push --quiet "$remote" "refs/tags/$tag"
  [[ "$(git ls-remote "$remote" "refs/tags/$tag^{}" | cut -f1)" == "$head" ]] \
    || die "$remote does not show $tag on $head; stopping before the GitHub release"

  if gh release view "$tag" --repo "$github_repo" >/dev/null 2>&1; then
    say "GitHub release $tag already exists"
  else
    local notes
    notes="$(mktemp)"
    write_notes "$v" "$notes" "$image"
    local assets=("$image")
    mapfile -t -O 1 assets < <(gallery_files "$v")
    gh release create "$tag" "${assets[@]}" --repo "$github_repo" --verify-tag --latest \
      --title "$title" --notes-file "$notes"
    rm -f "$notes"
  fi

  "$script_dir/wiki-sync.sh" publish "docs: sync wiki for $tag"

  local issue
  for issue in $fixed; do
    if [[ "$(gh issue view "$issue" --repo "$github_repo" --json state -q .state 2>/dev/null)" == "OPEN" ]]; then
      gh issue close "$issue" --repo "$github_repo" --reason completed \
        --comment "Fixed in [$tag](https://github.com/${github_repo}/releases/tag/$tag)." >/dev/null
      say "closed #$issue"
    fi
  done

  if [[ "$branch" != "prerelease" ]]; then
    say "published from $branch: merge main into prerelease so the next cycle starts from it"
  fi
  say "done: https://github.com/${github_repo}/releases/tag/$tag"
}

main() {
  local cmd="${1:-}"
  [[ -n "$cmd" && -n "${2:-}" ]] || { usage; exit 1; }
  require_version "$2"
  case "$cmd" in
    prepare) cmd_prepare "$2" ;;
    check) run_check "$2" "${3:-}" ;;
    publish) cmd_publish "$2" "${3:-}" ;;
    notes)
      local image
      image="$(readme_release_image || true)"
      if [[ -n "${3:-}" ]]; then
        write_notes "$2" "$3" "$image"
      else
        local tmp
        tmp="$(mktemp)"
        write_notes "$2" "$tmp" "$image"
        cat "$tmp"
        rm -f "$tmp"
      fi
      ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
