# shellcheck shell=bash
# The inir binary (snowarch/inir-cli), required (docs/adr/0007): the shell runs it, scripts/inir hands over to it and
# the Hub lives in it. Every install and update fetches the tag `cli.version` in sdata/prebuilt.json names into
# ${XDG_DATA_HOME:-~/.local/share}/inir/cli/inir; INIR_FETCH_CLI=0 skips that (a package ships it, INIR_CLI names it),
# INIR_CLI_RELEASES points at another release directory (a mirror, or file:// in the bench). A failed or unverified
# download keeps the old copy.

# The binary that runs here, in the order the launcher looks for it.
inir_cli_binary_path() {
  local cli
  for cli in "${INIR_CLI:-}" "${XDG_DATA_HOME:-$HOME/.local/share}/inir/cli/inir" \
             /usr/local/lib/inir/inir /usr/lib/inir/inir; do
    [[ -n "$cli" && -f "$cli" && -x "$cli" ]] || continue
    "$cli" cli version >/dev/null 2>&1 && { printf '%s\n' "$cli"; return 0; }
  done
  return 1
}

# Fetches the pinned binary; true only when one that runs is here afterwards (the new one, or the copy a failed
# download kept).
require_inir_cli_binary() {
  install_inir_cli_binary
  inir_cli_binary_path >/dev/null && return 0
  printf '  the inir command is required and none runs here%s\n' \
    "$([[ "${INIR_FETCH_CLI:-1}" == 1 ]] || printf ' (INIR_FETCH_CLI=0: the package or INIR_CLI must provide it)')" >&2
  return 1
}

install_inir_cli_binary() {
  [[ "${INIR_FETCH_CLI:-1}" == 1 ]] || return 0
  local arch
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) return 0 ;;
  esac
  # the tag this base was proved with, never "latest": a new cli reaches people with the base it was tested on
  local version base
  # read without jq: a fresh system fetches this before any package is installed
  local pin
  for pin in "${REPO_ROOT:-.}/sdata/prebuilt.json" "$(dirname "${BASH_SOURCE[0]}")/../prebuilt.json"; do
    [[ -n "$version" || ! -f "$pin" ]] && continue
    version="$(sed -n '/"cli"/,/}/s/.*"version": *"\([^"]*\)".*/\1/p' "$pin" | head -n1)"
  done
  base="${INIR_CLI_RELEASES:-https://github.com/snowarch/inir-cli/releases/download/v${version:-0.2.0}}"
  local dest="${XDG_DATA_HOME:-$HOME/.local/share}/inir/cli"
  local name="inir_linux_${arch}.tar.gz" tmp out rc=1 why=""
  tmp="$(mktemp -d)" || return 1
  # each step says what failed, on stderr: a quiet failure surfaced later as "could not get your families".
  # It is tried where it will run: a temp dir is often mounted noexec, and then nothing there runs.
  if ! curl -fsSL --retry 2 --max-time 60 -o "$tmp/$name" "$base/$name"; then
    why="could not download $base/$name"
  elif ! curl -fsSL --retry 2 --max-time 30 -o "$tmp/checksums.txt" "$base/checksums.txt"; then
    why="could not download $base/checksums.txt"
  elif ! (cd "$tmp" && grep -E "  ${name}\$" checksums.txt | sha256sum -c --status -); then
    why="$name does not match the release's checksums.txt"
  elif ! tar -xzf "$tmp/$name" -C "$tmp" --no-same-owner inir; then
    why="$name could not be unpacked"
  elif ! { mkdir -p "$dest" && install -m 0755 "$tmp/inir" "$dest/inir.new"; }; then
    why="could not write $dest/inir"
  elif ! out="$("$dest/inir.new" cli version 2>&1)"; then
    why="the downloaded inir does not run on this system (${out%%$'\n'*})"
    rm -f "$dest/inir.new"
  elif ! mv -f "$dest/inir.new" "$dest/inir"; then
    why="could not write $dest/inir"
  else
    rc=0
  fi
  rm -rf "$tmp"
  [[ -z "$why" ]] || printf '  inir command %s: %s; the copy already here, if any, stays\n' "v${version:-0.2.0}" "$why" >&2
  return $rc
}
