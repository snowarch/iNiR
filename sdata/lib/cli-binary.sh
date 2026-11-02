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
  version="$(jq -r '.cli.version // empty' "${REPO_ROOT:-.}/sdata/prebuilt.json" 2>/dev/null)"
  [[ -n "$version" ]] || version="$(jq -r '.cli.version // empty' "$(dirname "${BASH_SOURCE[0]}")/../prebuilt.json" 2>/dev/null)"
  base="${INIR_CLI_RELEASES:-https://github.com/snowarch/inir-cli/releases/download/v${version:-0.2.0}}"
  local dest="${XDG_DATA_HOME:-$HOME/.local/share}/inir/cli"
  local name="inir_linux_${arch}.tar.gz" tmp rc=1
  tmp="$(mktemp -d)" || return 1
  if curl -fsSL --retry 2 --max-time 60 -o "$tmp/$name" "$base/$name" \
      && curl -fsSL --retry 2 --max-time 30 -o "$tmp/checksums.txt" "$base/checksums.txt" \
      && (cd "$tmp" && grep -E "  ${name}\$" checksums.txt | sha256sum -c --status -) \
      && tar -xzf "$tmp/$name" -C "$tmp" inir \
      && "$tmp/inir" cli version >/dev/null 2>&1 \
      && mkdir -p "$dest" && install -m 0755 "$tmp/inir" "$dest/inir.new" && mv -f "$dest/inir.new" "$dest/inir"; then
    rc=0
  fi
  rm -rf "$tmp"
  return $rc
}
