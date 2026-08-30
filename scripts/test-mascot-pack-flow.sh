#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_STATE_HOME="$tmp/state"
export INIR_MASCOT_RELEASE_TAG="v-test"
export INIR_MASCOT_RELEASE_BASE_URL="file://${tmp}/release"

shell_dir="${XDG_CONFIG_HOME}/quickshell/inir"
asset_dir="${shell_dir}/assets/images/mascot"
helper_dir="${shell_dir}/scripts/lib"
mkdir -p "$asset_dir" "$helper_dir" "$tmp/release" "$tmp/source"
cp "$repo_root/scripts/lib/mascot-pack.py" "$helper_dir/mascot-pack.py"
printf '{"owner":"inir"}\n' > "$asset_dir/manifest.json"

for index in $(seq 1 11); do
  printf 'asset-%s\n' "$index" > "$tmp/source/inir-mascot-test-${index}.png"
done
printf 'required-loop\n' > "$tmp/source/inir-mascot-presence-idle-loop.gif"
(
  cd "$tmp/source"
  tar -czf "$tmp/release/inir-mascot-pack.tar.gz" inir-mascot-*
)

python3 - "$tmp/release/inir-mascot-pack.tar.gz" "$tmp/source" "$tmp/release/inir-mascot-pack.json" <<'PY'
import hashlib, json, sys
from pathlib import Path
archive, source, output = map(Path, sys.argv[1:])
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
tree = hashlib.sha256()
files = sorted(source.iterdir(), key=lambda path: path.name)
for path in files:
    tree.update(f"{digest(path)}  {path.name}\n".encode())
output.write_text(json.dumps({
    "schema": 1,
    "archive": archive.name,
    "asset_count": len(files),
    "archive_sha256": digest(archive),
    "asset_tree_sha256": tree.hexdigest(),
    "required_assets": ["inir-mascot-presence-idle-loop.gif"],
}, indent=2) + "\n")
PY

# Extras is sourced by setup in production. Stub only its presentation helpers.
tui_info() { :; }
tui_dim() { :; }
log_warning() { :; }
log_success() { :; }
# shellcheck source=../sdata/lib/extras.sh
source "$repo_root/sdata/lib/extras.sh"

extras_install_mascot_pack
[[ "$(find "$asset_dir" -maxdepth 1 -type f \( -name 'inir-mascot-*.png' -o -name 'inir-mascot-*.gif' \) | wc -l)" -eq 12 ]]
grep -Fq '"owner":"inir"' "$asset_dir/manifest.json"
state_file="${XDG_STATE_HOME}/inir/mascot-pack-state.json"
[[ -f "$state_file" ]]
python3 - "$state_file" <<'PY'
import json, sys
state = json.load(open(sys.argv[1]))
assert state["schema"] == 1
assert state["tag"] == "v-test"
assert state["asset_count"] == 12
assert len(state["asset_tree_sha256"]) == 64
PY

# Same release tag, damaged tree: refresh must repair instead of trusting the tag.
rm "$asset_dir/inir-mascot-test-4.png"
extras_refresh_mascot_pack_on_update
[[ -f "$asset_dir/inir-mascot-test-4.png" ]]

# Invalid archive must never replace the verified installed tree.
before="$(python3 "$helper_dir/mascot-pack.py" tree "$asset_dir")"
mkdir -p "$tmp/bad-release"
python3 - "$tmp/bad-release/inir-mascot-pack.tar.gz" <<'PY'
import io, sys, tarfile
with tarfile.open(sys.argv[1], "w:gz") as archive:
    info = tarfile.TarInfo("../escape.png")
    payload = b"bad"
    info.size = len(payload)
    archive.addfile(info, io.BytesIO(payload))
PY
export INIR_MASCOT_RELEASE_TAG="v-bad"
export INIR_MASCOT_RELEASE_BASE_URL="file://${tmp}/bad-release"
extras_install_mascot_pack

after="$(python3 "$helper_dir/mascot-pack.py" tree "$asset_dir")"
[[ "$before" == "$after" ]]
grep -Fq '"owner":"inir"' "$asset_dir/manifest.json"

printf 'mascot pack flow checks passed\n'
