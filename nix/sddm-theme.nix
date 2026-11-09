# The ii-pixel login screen setup installs for SDDM on other distros (scripts/sddm/install-pixel-sddm.sh), built
# read-only: its colours stay the theme's own and its background is `background` (black when null), since the
# shell cannot write the wallpaper and colours into the store the way it does in /usr/share/sddm/themes elsewhere.
{ pkgs, background ? null }:

pkgs.runCommand "inir-sddm-theme" { } ''
  theme="$out/share/sddm/themes/ii-pixel"
  mkdir -p "$theme/assets" "$theme/shapes" "$theme/fonts"
  cp -r ${../dots/sddm/pixel}/. "$theme/"
  cp -r ${../modules/common/widgets/shapes}/. "$theme/shapes/"
  cp ${../assets/fonts/rubik}/Rubik-*.ttf "$theme/fonts/"
  for weight in Regular Medium SemiBold Bold; do cp ${../assets/fonts/inter}/Inter-$weight.ttf "$theme/fonts/"; done
  symbols="$(find ${pkgs.material-symbols} -name 'MaterialSymbolsRounded*.ttf' | head -1)"
  [ -n "$symbols" ] && cp "$symbols" "$theme/fonts/MaterialSymbolsRounded.ttf"
  ${if background != null then ''cp ${background} "$theme/assets/background.png"''
    else ''base64 -d <<<'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGMQkVYAAACWAFAcPXLAAAAAAElFTkSuQmCC' > "$theme/assets/background.png"''}
''
