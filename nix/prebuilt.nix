# The binaries every iNiR install runs, at the versions the base pins in sdata/prebuilt.json (the same release files
# setup fetches on other distros, checked by the same sha256): qs-rs (Quickshell in Rust with its own Qt), inir-accel
# and the inir command. Nixpkgs builds none of them, so the release files are patched for the store: qs-rs and
# inir-accel get their interpreter and libraries from nixpkgs, the inir command is static.
# Each part keeps the layout setup gives it under ~/.local/share/inir (<dest>/<version>/ with its .sha256), so setup
# links them there and the shell, `inir doctor` and `inir version` find them exactly as on any distro.
{ pkgs, withWebEngine ? false }:

let
  inherit (pkgs) lib stdenv fetchurl;
  pins = lib.importJSON ../sdata/prebuilt.json;
  arch = stdenv.hostPlatform.uname.processor;
  goarch = { x86_64 = "amd64"; aarch64 = "arm64"; }.${arch};

  # the release file of a pin, from the URL template the pins name (the hosting it moves to keeps the sha256)
  release = { repo, version, file, sha256, ... }: fetchurl {
    url = lib.replaceStrings [ "{repo}" "{version}" "{file}" ] [ repo version file ] pins.fallback;
    inherit sha256;
  };

  # nixpkgs renamed the X11 libraries to top-level names; older channels keep them under xorg
  x11 = name: old: pkgs.${name} or pkgs.xorg.${old};

  qsPin = pins.parts.qs-rs;
  webPin = pins.parts.qs-rs-webengine // { inherit (qsPin) version; };
  accelPin = if arch == "x86_64" then pins.parts.inir-accel else pins.parts."inir-accel-${arch}";
in
rec {
  # qs-rs is built for x86_64 alone (sdata/prebuilt.json); on aarch64 the shell runs on nixpkgs' Quickshell
  qs-rs = if arch != "x86_64" then null else stdenv.mkDerivation {
    pname = "qs-rs" + lib.optionalString withWebEngine "-webengine";
    inherit (qsPin) version;
    srcs = [ (release qsPin) ] ++ lib.optional withWebEngine (release webPin);
    dontUnpack = true;
    dontStrip = true;
    dontWrapQtApps = true;

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [
      stdenv.cc.cc.lib
      brotli
      bzip2
      dbus
      fontconfig
      freetype
      glib
      krb5
      libdrm
      libglvnd
      libpulseaudio
      libxkbcommon
      linux-pam
      pipewire
      wayland
      zlib
      zstd
      (x11 "libx11" "libX11")
      (x11 "libxext" "libXext")
      (x11 "libxrandr" "libXrandr")
    ] ++ lib.optionals withWebEngine [
      alsa-lib
      expat
      libgbm
      nspr
      nss
      systemd
      (x11 "libxcb" "libxcb")
      (x11 "libxcomposite" "libXcomposite")
      (x11 "libxdamage" "libXdamage")
      (x11 "libxfixes" "libXfixes")
      (x11 "libxkbfile" "libxkbfile")
      (x11 "libxtst" "libXtst")
    ];
    # what Qt opens by name at run time: TLS, VA-API video, Vulkan, the GPU driver
    appendRunpaths = [
      "${lib.getLib pkgs.openssl}/lib"
      "${lib.getLib pkgs.libva}/lib"
      "${lib.getLib pkgs.vulkan-loader}/lib"
      "/run/opengl-driver/lib"
    ];

    installPhase = ''
      runHook preInstall
      dir="$out/${qsPin.dest}/${qsPin.version}"
      mkdir -p "$dir"
      tar -xzf ${release qsPin} -C "$dir" --strip-components=1 --no-same-owner
      echo ${qsPin.sha256} > "$dir/.sha256"
    '' + lib.optionalString withWebEngine ''
      tar -xzf ${release webPin} -C "$dir" --strip-components=1 --no-same-owner
      echo ${webPin.sha256} > "$dir/.qs-rs-webengine.sha256"
    '' + ''
      runHook postInstall
    '';

    meta = {
      description = "Quickshell in Rust with its own Qt, the runtime iNiR runs on";
      homepage = "https://github.com/snowarch/qs-rs";
      license = lib.licenses.lgpl3Only;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
    };
  };

  inir-accel = stdenv.mkDerivation {
    pname = "inir-accel";
    inherit (accelPin) version;
    src = release accelPin;
    dontStrip = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    installPhase = ''
      runHook preInstall
      dir="$out/${accelPin.dest}/${accelPin.version}"
      mkdir -p "$dir"
      cp -a . "$dir/"
      echo ${accelPin.sha256} > "$dir/.sha256"
      runHook postInstall
    '';
    meta = {
      description = "iNiR's native helpers: colours, regions, thumbnails and the Inir.Native QML plugin";
      homepage = "https://github.com/snowarch/inir-accel";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" "aarch64-linux" ];
    };
  };

  inir-cli = stdenv.mkDerivation {
    pname = "inir-cli";
    inherit (pins.cli) version;
    src = fetchurl {
      url = "https://github.com/snowarch/inir-cli/releases/download/v${pins.cli.version}/inir_linux_${goarch}.tar.gz";
      sha256 = pins.cli.sha256.${goarch};
    };
    sourceRoot = ".";
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 inir "$out/bin/inir"
      runHook postInstall
    '';
    meta = {
      description = "The inir command: the Hub, doctor, settings and the update";
      homepage = "https://github.com/snowarch/inir-cli";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" "aarch64-linux" ];
      mainProgram = "inir";
    };
  };
}
