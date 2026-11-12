# shellcheck shell=bash
# The inir binary (snowarch/inir-cli) next to the bash launcher, as ADR-0006 describes: scripts/inir
# hands over to ${XDG_DATA_HOME:-~/.local/share}/inir/cli/inir when it is there. The Hub lives in it, so
# every install and update fetches the tag `cli.version` in sdata/prebuilt.json names; INIR_FETCH_CLI=0 skips that, INIR_CLI_RELEASES points at another
# release directory (a mirror, or file:// in the bench). A failed or unverified download keeps the old copy.

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
  local name="inir_linux_${arch}.tar.gz" tmp rc=1 why=""
  tmp="$(mktemp -d)" || return 1
  # each step says what failed, on stderr: a quiet failure surfaced later as "could not get your families"
  if ! curl -fsSL --retry 2 --max-time 60 -o "$tmp/$name" "$base/$name"; then
    why="could not download $base/$name"
  elif ! curl -fsSL --retry 2 --max-time 30 -o "$tmp/checksums.txt" "$base/checksums.txt"; then
    why="could not download $base/checksums.txt"
  elif ! (cd "$tmp" && grep -E "  ${name}\$" checksums.txt | sha256sum -c --status -); then
    why="$name does not match the release's checksums.txt"
  elif ! tar -xzf "$tmp/$name" -C "$tmp" inir; then
    why="$name could not be unpacked"
  elif ! "$tmp/inir" cli version >/dev/null 2>&1; then
    why="the downloaded inir does not run on this system"
  elif ! { mkdir -p "$dest" && install -m 0755 "$tmp/inir" "$dest/inir.new" && mv -f "$dest/inir.new" "$dest/inir"; }; then
    why="could not write $dest/inir"
  else
    rc=0
  fi
  rm -rf "$tmp"
  [[ -z "$why" ]] || printf '  inir command %s: %s; the copy already here, if any, stays\n' "v${version:-0.2.0}" "$why" >&2
  return $rc
}
