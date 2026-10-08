#!/usr/bin/env bash
set -euo pipefail
# LiMusic reads ~/.config/limusic/matugen.css, adds it as a <style> after its own sheet and
# re-reads it whenever the file changes (upstream PR SimoHypers/limusic#351). The file only sets
# LiMusic's shadcn tokens, so every theme preset, light and dark, takes the iNiR palette. Releases
# without that support read the same file through iNiR's WebKit theme module (see below).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="limusic"

LIMUSIC_CSS="$XDG_CONFIG_HOME/limusic/matugen.css"
COLORS_JSON="$STATE_DIR/user/generated/app-palette.json"
[[ -f "$COLORS_JSON" ]] || COLORS_JSON="$STATE_DIR/user/generated/palette.json"
[[ -f "$COLORS_JSON" ]] || COLORS_JSON="$STATE_DIR/user/generated/colors.json"

limusic_installed() {
  [[ -d "$XDG_CONFIG_HOME/com.limusic.desktop" || -d "${XDG_DATA_HOME:-$HOME/.local/share}/com.limusic.desktop" ]] && return 0
  [[ -d "$XDG_CONFIG_HOME/limusic" ]] && return 0
  command -v limusic >/dev/null 2>&1 || command -v limusic-app >/dev/null 2>&1
}

read_hex() {
  local token="$1" fallback="${2:-#000000}" hex
  hex=$(jq -r ".${token} // empty" "$COLORS_JSON" 2>/dev/null) || true
  printf '%s' "${hex:-$fallback}"
}

generate_limusic_css() {
  local bg fg card popover raised hover subtext border accent on_accent sidebar error
  local chart2 chart3 chart4 chart5
  bg=$(read_hex 'app_background // .surface' "#121318")
  fg=$(read_hex 'app_foreground // .on_surface' "#e3e2e9")
  card=$(read_hex 'app_surface // .surface_container_low' "#1a1b20")
  popover=$(read_hex 'app_surface_popup // .surface_container_high' "#292a2f")
  raised=$(read_hex 'app_surface_elevated // .surface_container' "#1e1f25")
  hover=$(read_hex 'app_surface_hover // .surface_container_high' "#292a2f")
  subtext=$(read_hex 'app_subtext // .on_surface_variant' "#c5c6d0")
  border=$(read_hex 'app_border_subtle // .outline_variant' "#44464f")
  accent=$(read_hex 'app_accent // .primary' "#b2c5ff")
  on_accent=$(read_hex 'app_on_accent // .on_primary' "#182e60")
  sidebar=$(read_hex 'app_sidebar_bg // .app_background // .surface' "#121318")
  error=$(read_hex error "#ffb4ab")
  chart2=$(read_hex secondary "#c1c6dd")
  chart3=$(read_hex tertiary "#e1bbdc")
  chart4=$(read_hex 'app_accent_container // .primary_container' "#304578")
  chart5=$(read_hex outline "#8e9099")

  cat <<EOCSS
/* iNiR — LiMusic. Generated from the current palette; edits are overwritten. */

/* Outranks LiMusic's presets (.dark.theme-x is 0,2,0) without a class of its own, so it holds
   whichever preset or mode is selected. */
html:root:root {
  --foreground: ${fg};
  --card-foreground: ${fg};
  --popover-foreground: ${fg};
  --primary: ${accent};
  --primary-foreground: ${on_accent};
  --secondary-foreground: ${fg};
  --muted-foreground: ${subtext};
  --accent: ${accent};
  --accent-foreground: ${on_accent};
  --destructive: ${error};
  --border: ${border};
  --input: ${border};
  --ring: ${accent};
  --chart-1: ${accent};
  --chart-2: ${chart2};
  --chart-3: ${chart3};
  --chart-4: ${chart4};
  --chart-5: ${chart5};
  --sidebar-foreground: ${fg};
  --sidebar-primary: ${accent};
  --sidebar-primary-foreground: ${on_accent};
  --sidebar-accent-foreground: ${fg};
  --sidebar-border: ${border};
  --sidebar-ring: ${accent};
  color-scheme: $(theme_mode);
}

/* Fills. "Adapt colors to artwork" tints these from the cover, so they step aside while it is on. */
html:root:root:not(.art-tint) {
  --background: ${bg};
  --card: ${card};
  --popover: ${popover};
  --secondary: ${raised};
  --muted: ${raised};
  --sidebar: ${sidebar};
  --sidebar-accent: ${hover};
}
EOCSS
}

# LiMusic releases before #351 have no way in. A small GTK module (webkit-theme/inir-webkit-theme.c) adds the
# same file as a WebKit user stylesheet and swaps it when it changes; the launcher loads it through GTK_MODULES.
WEBKIT_THEME_SRC="$SCRIPT_DIR/webkit-theme/inir-webkit-theme.c"
WEBKIT_THEME_SO="$STATE_DIR/user/generated/bin/libinir-webkit-theme.so"

build_webkit_theme_module() {
  [[ -f "$WEBKIT_THEME_SO" && "$WEBKIT_THEME_SO" -nt "$WEBKIT_THEME_SRC" ]] && return 0
  local cc
  cc="$(command -v cc || command -v gcc || command -v clang || true)"
  if [[ -z "$cc" ]]; then
    log_module "no C compiler (install gcc) — LiMusic needs a release with Matugen theme support instead"
    return 1
  fi
  mkdir -p "$(dirname "$WEBKIT_THEME_SO")"
  if "$cc" -shared -fPIC -O2 -o "$WEBKIT_THEME_SO.tmp" "$WEBKIT_THEME_SRC" -ldl 2>>"$MODULE_LOG"; then
    mv -f "$WEBKIT_THEME_SO.tmp" "$WEBKIT_THEME_SO"
    log_module "built $WEBKIT_THEME_SO"
    return 0
  fi
  rm -f "$WEBKIT_THEME_SO.tmp"
  log_module "could not build the LiMusic theme module"
  return 1
}

# Every LiMusic launcher (AppImageLauncher, AUR, deb/rpm) gets GTK_MODULES on the Exec lines that run LiMusic itself,
# not on actions such as AppImageLauncher's "remove". A system entry is copied to ~/.local/share/applications first.
limusic_launchers() {
  local user_apps="$HOME/.local/share/applications" entry
  grep -lisE '^Exec=.*limusic' "$user_apps"/*.desktop /usr/share/applications/*.desktop 2>/dev/null | while IFS= read -r entry; do
    [[ "$entry" == *.bak* ]] && continue
    printf '%s\n' "$entry"
  done
}

edit_launcher() {
  local path="$1" mode="$2"
  python3 - "$path" "$WEBKIT_THEME_SO" "$mode" <<'PY'
import sys
path, module, mode = sys.argv[1:4]
prefix = f'env "GTK_MODULES={module}" '
text = open(path).read()
out = []
for line in text.split("\n"):
    if line.startswith("Exec="):
        body = line[len("Exec="):]
        if mode == "remove":
            body = body.replace(prefix, "", 1)
        elif "GTK_MODULES=" not in body and "limusic" in body.split(" ")[0].lower():
            body = prefix + body
        line = "Exec=" + body
    out.append(line)
new = "\n".join(out)
if new != text:
    open(path, "w").write(new)
    print("changed")
PY
}

patch_limusic_launchers() {
  local user_apps="$HOME/.local/share/applications" entry target
  while IFS= read -r entry; do
    target="$user_apps/$(basename "$entry")"
    if [[ "$entry" != "$target" ]]; then
      [[ -f "$target" ]] && continue   # the user copy is the one in use; patched on its own pass
      mkdir -p "$user_apps"
      cp "$entry" "$target"
    fi
    if [[ "$(edit_launcher "$target" add)" == changed ]]; then
      log_module "LiMusic launcher $(basename "$target") loads the theme module (applies from LiMusic's next start)"
    fi
  done < <(limusic_launchers)
}

remove_limusic_theme() {
  local entry
  if [[ -f "$LIMUSIC_CSS" ]] && head -n1 "$LIMUSIC_CSS" | grep -q 'iNiR'; then
    rm -f "$LIMUSIC_CSS"
    log_module "removed $LIMUSIC_CSS"
  fi
  while IFS= read -r entry; do
    [[ "$entry" == "$HOME/.local/share/applications/"* ]] || continue
    if [[ "$(edit_launcher "$entry" remove)" == changed ]]; then
      log_module "LiMusic launcher $(basename "$entry") no longer loads the theme module"
    fi
  done < <(limusic_launchers)
}

main() {
  local enabled
  enabled=$(config_bool '.appearance.wallpaperTheming.enableLimusic' false)
  if [[ "$enabled" != 'true' ]]; then
    remove_limusic_theme
    exit 0
  fi

  limusic_installed || exit 0
  [[ -f "$COLORS_JSON" ]] || { log_module "no generated palette — skipping"; exit 0; }
  command -v jq >/dev/null 2>&1 || { log_module "jq not installed — skipping"; exit 0; }

  mkdir -p "$(dirname "$LIMUSIC_CSS")"
  if generate_limusic_css | write_if_changed "$LIMUSIC_CSS"; then
    log_module "wrote $LIMUSIC_CSS"
  fi

  build_webkit_theme_module && patch_limusic_launchers
  return 0
}

main "$@"
