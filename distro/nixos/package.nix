{
  stdenvNoCC,
  makeWrapper,
  lib,

  bash,
  bc,
  coreutils,
  curl,
  findutils,
  gawk,
  git,
  gnugrep,
  gnused,
  jq,
  procps,
  python3,
  ripgrep,
  rsync,
  systemd,
  wget,
  xdg-utils,
  quickshell,
  wl-clipboard,
  cliphist,
  grim,
  slurp,
  playerctl,
  libnotify,
  glib,
  pipewire,
  pulseaudio,
  wireplumber,

  brightnessctl,
  cava,
  ddcutil,
  ffmpeg,
  fish,
  foot,
  fuzzel,
  geoclue2,
  hyprland,
  hyprpicker,
  gum,
  imagemagick,
  kitty,
  libqalculate,
  mpv,
  nautilus,
  networkmanager,
  socat,
  songrec,
  swappy,
  tesseract,
  translate-shell,
  upower,
  wf-recorder,
  wlsunset,
  wtype,
  xwayland-satellite,
  ydotool,

  kdePackages,
  qt6,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "inir";
  version = "2.28.0";

  src = lib.cleanSource ./../..;

  nativeBuildInputs = [ makeWrapper ];

  preFixup = ''
    find "$out/share/quickshell/inir" -type f -name '*.py' -exec chmod -x {} +
  '';

  postFixup = ''
    find "$out/share/quickshell/inir" -type f -name '*.py' -exec chmod +x {} +
  '';

  installPhase =
    let
      deps = [
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

        brightnessctl
        cava
        ddcutil
        ffmpeg
        fish
        foot
        fuzzel
        geoclue2
        hyprland
        hyprpicker
        gum
        imagemagick
        kitty
        libqalculate
        mpv
        nautilus
        networkmanager
        socat
        songrec
        swappy
        tesseract
        translate-shell
        upower
        wf-recorder
        wlsunset
        wtype
        xwayland-satellite
        ydotool

        kdePackages.breeze-icons
        kdePackages.kdialog
        kdePackages.kirigami
        kdePackages.kconfig
        kdePackages.plasma-integration
        kdePackages.syntax-highlighting
        qt6.qt5compat
        qt6.qtbase
        qt6.qtdeclarative
        qt6.qtimageformats
        qt6.qtmultimedia
        qt6.qtpositioning
        qt6.qtquicktimeline
        qt6.qtsensors
        qt6.qtsvg
        qt6.qttools
        qt6.qttranslations
        qt6.qtvirtualkeyboard
        qt6.qtwayland
      ];
      qml = [
        kdePackages.kirigami.passthru.unwrapped
        kdePackages.syntax-highlighting
        qt6.qt5compat
        qt6.qtdeclarative
        qt6.qtimageformats
        qt6.qtmultimedia
        qt6.qtpositioning
        qt6.qtquicktimeline
        qt6.qtsensors
        qt6.qtsvg
        qt6.qtvirtualkeyboard
        qt6.qtwayland
      ];
    in
    ''
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

      # The source tree intentionally targets Arch, where helpers live
      # under /usr/bin. NixOS does not provide that layout. Patch only
      # the packaged copy and keep shebang lines intact.
      find "$runtime/modules" "$runtime/services" "$runtime/defaults" "$runtime/scripts" \
        -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name '*.py' \) \
        -exec sed -i '1!s#/usr/bin/##g' {} +

      makeWrapper "$runtime/scripts/inir" "$out/bin/inir" \
        --prefix PATH : "${lib.makeBinPath deps}" \
        --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" qml}" \
        --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" qml}" \
        --set-default INIR_SYSTEM_RUNTIME_DIR "$runtime" \
        --set-default INIR_FALLBACK_SYSTEM_RUNTIME_DIR "$runtime"

      runHook postInstall
    '';
})
