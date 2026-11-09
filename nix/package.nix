# iNiR for Nix, the same install every distro gets:
# - the base as a read-only payload ($out/share/quickshell/inir), of which setup keeps the person's writable copy in
#   ~/.config/quickshell/inir with the families from inir.space/hub, exactly as on Arch;
# - the binaries every install runs at the versions the base pins (prebuilt.nix), linked by setup where it would
#   unpack them;
# - `inir`, which syncs the person's copy the first time it runs after the package moved, then starts the shell.
# The base moves with the package (`nix flake update`); hub items update themselves (`inir update`, Settings › Hub).
{ pkgs
, withWebEngine ? false
, commit ? "unknown"
, updateHint ? "nix flake update inir, then rebuild"
}:

let
  inherit (pkgs) lib;
  prebuilt = import ./prebuilt.nix { inherit pkgs withWebEngine; };
  deps = import ./deps.nix { inherit pkgs; };
  version = lib.removeSuffix "\n" (builtins.readFile ../VERSION);

  # where qs-rs has no build the shell runs on nixpkgs' Quickshell, which finds its QML modules here
  quickshell = pkgs.symlinkJoin {
    name = "inir-quickshell-${pkgs.quickshell.version}";
    paths = [ pkgs.quickshell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in qs quickshell; do
        [ -e "$out/bin/$bin" ] || continue
        wrapProgram "$out/bin/$bin" \
          --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" deps.qml}" \
          --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" deps.qml}"
      done
    '';
  };
  path = [ quickshell ] ++ lib.remove pkgs.quickshell deps.packages;

  # the parts by <dest>/<version>, the layout setup links into ~/.local/share/inir (INIR_PREBUILT_STORE)
  parts = lib.filter (part: part != null) [ prebuilt.qs-rs prebuilt.inir-accel ];
  linkPart = part: ''
    for dir in ${part}/*/*; do
      mkdir -p "$store/$(basename "$(dirname "$dir")")"
      ln -s "$dir" "$store/$(basename "$(dirname "$dir")")/"
    done
  '';
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "inir";
  inherit version;
  src = lib.cleanSourceWith {
    src = ../.;
    filter = import ./runtime-source-filter.nix { inherit lib; root = ../.; };
  };

  nativeBuildInputs = [ pkgs.makeWrapper pkgs.jq pkgs.rsync ];
  # setup and the scripts are run by the person's copy, never from the store: they keep their /usr/bin/env lines
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall

    payload="$out/share/quickshell/inir"
    store="$out/lib/inir/prebuilt"
    mkdir -p "$payload" "$store" "$out/bin" "$out/share/applications" "$out/share/icons/hicolor/scalable/apps"

    bash -c 'source sdata/lib/runtime-payload.sh && runtime_payload copy --root . --target "$1"' _ "$payload"
    chmod +x "$payload/setup" "$payload/scripts/inir"

    jq -n --arg v ${lib.escapeShellArg version} --arg c ${lib.escapeShellArg commit} --arg h ${lib.escapeShellArg updateHint} '{
      version: $v, commit: $c, source: "nix",
      installMode: "package-managed", updateStrategy: "package-manager",
      packageManager: "nix", packageName: "inir", packageUpdateHint: $h
    }' > "$payload/version.json"

    ${lib.concatMapStrings linkPart parts}

    # gsettings finds no schema on NixOS outside GNOME, and the shell's dark mode, icons and fonts reach GTK apps
    # through it: gsettings-desktop-schemas goes last in XDG_DATA_DIRS, so a desktop's own schemas still win
    makeWrapper "$payload/scripts/inir" "$out/bin/inir" \
      --suffix PATH : ${lib.makeBinPath path} \
      --suffix XDG_DATA_DIRS : ${pkgs.glib.getSchemaDataDirPath pkgs.gsettings-desktop-schemas} \
      --set INIR_CLI ${lib.getExe prebuilt.inir-cli} \
      --set INIR_FETCH_CLI 0 \
      --set INIR_PREBUILT_STORE "$store" \
      --set INIR_SETUP_DIR "$payload"

    install -Dm644 "$payload/assets/icons/inir.svg" "$out/share/icons/hicolor/scalable/apps/inir.svg"
    sed 's|^Exec=.*|Exec=inir service restart|' "$payload/assets/applications/inir.desktop" > "$out/share/applications/inir.desktop"
    sed 's|^Exec=.*|Exec=inir settings|' "$payload/assets/applications/inir-settings.desktop" > "$out/share/applications/inir-settings.desktop"

    runHook postInstall
  '';

  passthru = {
    inherit prebuilt deps quickshell;
    runtimeDependencies = path;
  };

  meta = {
    description = "Complete desktop shell for Niri";
    homepage = "https://inir.space";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "inir";
  };
}
