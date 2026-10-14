# shellcheck shell=bash
# The inir binary (snowarch/inir-cli) next to the bash launcher, as ADR-0006 describes: scripts/inir
# hands over to ${XDG_DATA_HOME:-~/.local/share}/inir/cli/inir when it is there. Opt-in with
# INIR_FETCH_CLI=1 until the releases are public; INIR_CLI_RELEASES points at another release
# directory (a mirror, or file:// in the bench). A failed or unverified download keeps the old copy.

install_inir_cli_binary() {
  [[ "${INIR_FETCH_CLI:-0}" == 1 ]] || return 0
  local arch
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) return 0 ;;
  esac
  local base="${INIR_CLI_RELEASES:-https://github.com/snowarch/inir-cli/releases/latest/download}"
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
