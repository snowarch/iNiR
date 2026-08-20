{ pkgs }:

let
  lib = pkgs.lib;

  optionalTop = name:
    lib.optional (builtins.hasAttr name pkgs) (builtins.getAttr name pkgs);

  optionalKde = name:
    lib.optional
      (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr name pkgs.kdePackages)
      (builtins.getAttr name pkgs.kdePackages);

  optionalQt6 = name:
    lib.optional
      (builtins.hasAttr "qt6" pkgs && builtins.hasAttr name pkgs.qt6)
      (builtins.getAttr name pkgs.qt6);

  runtimeDeps =
    with pkgs; [
      bash
      bc
      coreutils
      curl
      findutils
      gawk
      git
      gnugrep
      gnused
      jq
      procps
      python3
      ripgrep
      rsync
      systemd
      wget
      xdg-utils

      quickshell
      wl-clipboard
      cliphist
      grim
      slurp
      playerctl
      libnotify
      glib
      pipewire
      pulseaudio
      wireplumber
    ]
    ++ optionalTop "brightnessctl"
    ++ optionalTop "cava"
    ++ optionalTop "ddcutil"
    ++ optionalTop "ffmpeg"
    ++ optionalTop "fish"
    ++ optionalTop "foot"
    ++ optionalTop "fuzzel"
    ++ optionalTop "geoclue2"
    ++ optionalTop "hyprland"
    ++ optionalTop "hyprpicker"
    ++ optionalTop "gum"
    ++ optionalTop "imagemagick"
    ++ optionalTop "kitty"
    ++ optionalTop "libqalculate"
    ++ optionalTop "mpv"
    ++ optionalTop "nautilus"
    ++ optionalTop "networkmanager"
    ++ optionalTop "socat"
    ++ optionalTop "songrec"
    ++ optionalTop "swappy"
    ++ optionalTop "tesseract"
    ++ optionalTop "translate-shell"
    ++ optionalTop "upower"
    ++ optionalTop "wf-recorder"
    ++ optionalTop "wlsunset"
    ++ optionalTop "wtype"
    ++ optionalTop "xwayland-satellite"
    ++ optionalTop "ydotool"
    ++ optionalKde "breeze-icons"
    ++ optionalKde "kdialog"
    ++ optionalKde "kirigami"
    ++ optionalKde "kconfig"
    ++ optionalKde "plasma-integration"
    ++ optionalKde "syntax-highlighting"
    ++ optionalKde "xembedsniproxy"
    ++ optionalQt6 "qt5compat"
    ++ optionalQt6 "qtbase"
    ++ optionalQt6 "qtdeclarative"
    ++ optionalQt6 "qtimageformats"
    ++ optionalQt6 "qtmultimedia"
    ++ optionalQt6 "qtpositioning"
    ++ optionalQt6 "qtquicktimeline"
    ++ optionalQt6 "qtsensors"
    ++ optionalQt6 "qtsvg"
    ++ optionalQt6 "qttools"
    ++ optionalQt6 "qttranslations"
    ++ optionalQt6 "qtvirtualkeyboard"
    ++ optionalQt6 "qtwayland";

  materialSymbolsFont =
    if builtins.hasAttr "material-symbols" pkgs
    then pkgs.makeFontsConf { fontDirectories = [ pkgs.material-symbols ]; }
    else null;
  materialSymbolsWrapperArg =
    lib.optionalString (materialSymbolsFont != null)
      "--set FONTCONFIG_FILE \"${materialSymbolsFont}\" \\";

  qmlDeps =
    # kirigami-wrapped ships no QML files, use the unwrapped version.
    (lib.optional
      (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr "kirigami" pkgs.kdePackages)
      pkgs.kdePackages.kirigami.passthru.unwrapped)
    ++ optionalKde "syntax-highlighting"
    ++ optionalQt6 "qt5compat"
    ++ optionalQt6 "qtdeclarative"
    ++ optionalQt6 "qtimageformats"
    ++ optionalQt6 "qtmultimedia"
    ++ optionalQt6 "qtpositioning"
    ++ optionalQt6 "qtquicktimeline"
    ++ optionalQt6 "qtsensors"
    ++ optionalQt6 "qtsvg"
    ++ optionalQt6 "qtvirtualkeyboard"
    ++ optionalQt6 "qtwayland";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "inir";
  version = lib.removeSuffix "\n" (builtins.readFile ../VERSION);
  src = lib.cleanSource ../.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # Prevent patchShebangs from attempting to rewrite Python scripts;
  # non-executable files are skipped during fixupPhase.
  preFixup = ''
    find "$out/share/quickshell/inir" -type f -name '*.py' -exec chmod -x {} +
  '';

  postFixup = ''
    find "$out/share/quickshell/inir" -type f -name '*.py' -exec chmod +x {} +
  '';

  installPhase = ''
    runHook preInstall

    runtime="$out/share/quickshell/inir"
    mkdir -p "$runtime" "$out/bin"

    while IFS= read -r path; do
      [ -n "$path" ] || continue
      install -Dm644 "$path" "$runtime/$path"
    done < sdata/runtime-root-files.txt

    while IFS= read -r dir; do
      [ -n "$dir" ] || continue
      cp -R "$dir" "$runtime/$dir"
    done < sdata/runtime-payload-dirs.txt

    # Copy root-level QML entry points (shell.qml, settings.qml, etc.)
    # which aren't listed in runtime-root-files.txt.
    for f in *.qml; do
      [ -f "$f" ] || continue
      install -Dm644 "$f" "$runtime/$f"
    done

    chmod +x "$runtime/setup" "$runtime/scripts/inir"
    find "$runtime/scripts" -type f \( -name '*.sh' -o -name '*.fish' -o -name '*.py' \) -exec chmod +x {} \;

    # The source tree intentionally targets Arch, where helpers live under
    # /usr/bin. NixOS does not provide that layout. Patch only the packaged
    # copy and keep shebang lines intact.
    find "$runtime/modules" "$runtime/services" "$runtime/defaults" "$runtime/scripts" \
      -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name '*.py' \) \
      -exec sed -i '1!s#/usr/bin/##g' {} +

    makeWrapper "$runtime/scripts/inir" "$out/bin/inir" \
      --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" qmlDeps}" \
      --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" qmlDeps}" \
      ${materialSymbolsWrapperArg}
      --set-default INIR_SYSTEM_RUNTIME_DIR "$runtime" \
      --set-default INIR_FALLBACK_SYSTEM_RUNTIME_DIR "$runtime"

    runHook postInstall
  '';

  passthru.runtimeDependencies = runtimeDeps;

  meta = {
    description = "Complete desktop shell for Niri, built on Quickshell";
    homepage = "https://github.com/snowarch/inir";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "inir";
  };
}
