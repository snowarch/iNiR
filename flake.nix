{
  description = "iNiR desktop shell for Niri, packaged for NixOS and Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      optionalTop = pkgs: name:
        lib.optional (builtins.hasAttr name pkgs) (builtins.getAttr name pkgs);

      optionalKde = pkgs: name:
        lib.optional
          (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr name pkgs.kdePackages)
          (builtins.getAttr name pkgs.kdePackages);

      optionalQt6 = pkgs: name:
        lib.optional
          (builtins.hasAttr "qt6" pkgs && builtins.hasAttr name pkgs.qt6)
          (builtins.getAttr name pkgs.qt6);

      runtimeDeps = pkgs:
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
        ++ optionalTop pkgs "brightnessctl"
        ++ optionalTop pkgs "cava"
        ++ optionalTop pkgs "ddcutil"
        ++ optionalTop pkgs "ffmpeg"
        ++ optionalTop pkgs "fish"
        ++ optionalTop pkgs "foot"
        ++ optionalTop pkgs "fuzzel"
        ++ optionalTop pkgs "geoclue2"
        ++ optionalTop pkgs "hyprland"
        ++ optionalTop pkgs "hyprpicker"
        ++ optionalTop pkgs "gum"
        ++ optionalTop pkgs "imagemagick"
        ++ optionalTop pkgs "kitty"
        ++ optionalTop pkgs "libqalculate"
        ++ optionalTop pkgs "mpv"
        ++ optionalTop pkgs "nautilus"
        ++ optionalTop pkgs "networkmanager"
        ++ optionalTop pkgs "socat"
        ++ optionalTop pkgs "songrec"
        ++ optionalTop pkgs "swappy"
        ++ optionalTop pkgs "tesseract"
        ++ optionalTop pkgs "translate-shell"
        ++ optionalTop pkgs "upower"
        ++ optionalTop pkgs "wf-recorder"
        ++ optionalTop pkgs "wlsunset"
        ++ optionalTop pkgs "wtype"
        ++ optionalTop pkgs "xwayland-satellite"
        ++ optionalTop pkgs "ydotool"
        ++ optionalKde pkgs "breeze-icons"
        ++ optionalKde pkgs "kdialog"
        ++ optionalKde pkgs "kirigami"
        ++ optionalKde pkgs "kconfig"
        ++ optionalKde pkgs "plasma-integration"
        ++ optionalKde pkgs "syntax-highlighting"
        ++ optionalKde pkgs "xembedsniproxy"
        ++ optionalQt6 pkgs "qt5compat"
        ++ optionalQt6 pkgs "qtbase"
        ++ optionalQt6 pkgs "qtdeclarative"
        ++ optionalQt6 pkgs "qtimageformats"
        ++ optionalQt6 pkgs "qtmultimedia"
        ++ optionalQt6 pkgs "qtpositioning"
        ++ optionalQt6 pkgs "qtquicktimeline"
        ++ optionalQt6 pkgs "qtsensors"
        ++ optionalQt6 pkgs "qtsvg"
        ++ optionalQt6 pkgs "qttools"
        ++ optionalQt6 pkgs "qttranslations"
        ++ optionalQt6 pkgs "qtvirtualkeyboard"
        ++ optionalQt6 pkgs "qtwayland";

      qmlDeps = pkgs:
        # kirigami-wrapped ships no QML files, use the unwrapped version
        (lib.optional
          (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr "kirigami" pkgs.kdePackages)
          pkgs.kdePackages.kirigami.passthru.unwrapped)
        ++ optionalKde pkgs "syntax-highlighting"
        ++ optionalQt6 pkgs "qt5compat"
        ++ optionalQt6 pkgs "qtdeclarative"
        ++ optionalQt6 pkgs "qtimageformats"
        ++ optionalQt6 pkgs "qtmultimedia"
        ++ optionalQt6 pkgs "qtpositioning"
        ++ optionalQt6 pkgs "qtquicktimeline"
        ++ optionalQt6 pkgs "qtsensors"
        ++ optionalQt6 pkgs "qtsvg"
        ++ optionalQt6 pkgs "qtvirtualkeyboard"
        ++ optionalQt6 pkgs "qtwayland";

      mkPackage = pkgs:
        pkgs.stdenvNoCC.mkDerivation {
          pname = "inir";
          version = lib.removeSuffix "\n" (builtins.readFile ./VERSION);
          src = lib.cleanSource ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          # Prevent patchShebangs from attempting to rewrite Python scripts;
          # non-executable files are skipped during fixupPhase.
          preFixup = ''
            find "$out/share/quickshell/inir" -type f -name '*.py' -exec chmod -x {} +
          '';

          postFixup = ''
            find "$out/share/quickshell/inir" -type f -name '*.py' -exec chmod +x {} +
          '';

          installPhase =
            let
              deps = runtimeDeps pkgs;
              qml = qmlDeps pkgs;
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

          passthru.runtimeDependencies = runtimeDeps pkgs;

          meta = {
            description = "Complete desktop shell for Niri, built on Quickshell";
            homepage = "https://github.com/snowarch/inir";
            license = lib.licenses.gpl3Only;
            platforms = lib.platforms.linux;
            mainProgram = "inir";
          };
        };

      commonOptions = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.inir;
          defaultPackage = self.packages.${pkgs.system}.default;
        in
        {
          options.programs.inir = {
            enable = lib.mkEnableOption "iNiR desktop shell";

            package = lib.mkOption {
              type = lib.types.package;
              default = defaultPackage;
              defaultText = lib.literalExpression "inputs.inir.packages.${pkgs.system}.default";
              description = "iNiR package to install and run.";
            };

            extraPackages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra runtime packages made available to the iNiR service.";
            };

            service = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Create the inir systemd user service.";
              };

              compositor = lib.mkOption {
                type = lib.types.nullOr (lib.types.enum [ "niri" "hyprland" ]);
                default = "niri";
                description = "Compositor user unit that should want inir.service. Set null to create the unit without auto-start wiring.";
              };
            };
          };
        };

      compositorUnit = compositor:
        if compositor == "niri" then "niri.service"
        else if compositor == "hyprland" then "wayland-wm@Hyprland.service"
        else null;

      serviceEnvironment = cfg: {
        INIR_SYSTEM_RUNTIME_DIR = "${cfg.package}/share/quickshell/inir";
        INIR_FALLBACK_SYSTEM_RUNTIME_DIR = "${cfg.package}/share/quickshell/inir";
        QS_DISABLE_CRASH_HANDLER = "1";
        QT_LOGGING_RULES = "quickshell.dbus.properties=false;qt.qml.settings.warning=false;qt.core.qsettings.warning=false;kf.xmlgui=false;kf.coreaddons=false;kf.config.core=false;kf.iconthemes=false";
        QT_SCALE_FACTOR = "1";
        QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
      };

      mkNixosModule = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.inir;
          wantedUnit = compositorUnit cfg.service.compositor;
        in
        {
          # commonOptions is itself a module; merging it via mkMerge would put
          # its `options` declarations on the config side and fail evaluation.
          imports = [ commonOptions ];

          config = lib.mkIf cfg.enable {
              environment.systemPackages = [ cfg.package ];

              systemd.user.services.inir = lib.mkIf cfg.service.enable {
                description = "iNiR shell";
                wantedBy = lib.optional (wantedUnit != null) wantedUnit;
                partOf = [ "graphical-session.target" ];
                after = [ "graphical-session.target" ];
                path = [ cfg.package ] ++ cfg.extraPackages;
                environment = serviceEnvironment cfg;
                unitConfig = {
                  Requisite = "graphical-session.target";
                  StartLimitIntervalSec = 30;
                  StartLimitBurst = 3;
                };
                serviceConfig = {
                  Type = "simple";
                  ExecStart = "${lib.getExe cfg.package} run --session";
                  ExecStopPost = "-${lib.getExe cfg.package} cleanup-orphans";
                  SuccessExitStatus = 143;
                  KillMode = "process";
                  KillSignal = "SIGTERM";
                  Restart = "on-failure";
                  RestartSec = 5;
                  TimeoutStopSec = 15;
                  LimitCORE = 0;
                  IOSchedulingPriority = 2;
                };
              };
            };
          };

      mkHomeModule = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.inir;
          wantedUnit = compositorUnit cfg.service.compositor;
          env = serviceEnvironment cfg;
        in
        {
          imports = [ commonOptions ];

          options.programs.inir.configSymlink = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Expose the packaged shell at ~/.config/quickshell/inir for tools that expect the traditional path.";
              };
            };

            config = lib.mkIf cfg.enable {
              home.packages = [ cfg.package ];

              xdg.configFile = lib.mkIf cfg.configSymlink.enable {
                "quickshell/inir".source = "${cfg.package}/share/quickshell/inir";
              };

              systemd.user.services.inir = lib.mkIf cfg.service.enable {
                Unit = {
                  Description = "iNiR shell";
                  PartOf = [ "graphical-session.target" ];
                  After = [ "graphical-session.target" ];
                  Requisite = [ "graphical-session.target" ];
                  StartLimitIntervalSec = 30;
                  StartLimitBurst = 3;
                };

                Service = {
                  Type = "simple";
                  Environment = lib.mapAttrsToList (name: value: "${name}=${value}") env;
                  ExecStart = "${lib.getExe cfg.package} run --session";
                  ExecStopPost = "-${lib.getExe cfg.package} cleanup-orphans";
                  SuccessExitStatus = 143;
                  KillMode = "process";
                  KillSignal = "SIGTERM";
                  Restart = "on-failure";
                  RestartSec = 5;
                  TimeoutStopSec = 15;
                  LimitCORE = 0;
                  IOSchedulingPriority = 2;
                };

                Install.WantedBy = lib.optional (wantedUnit != null) wantedUnit;
              };
            };
          };
    in
    {
      packages = forAllSystems (pkgs: {
        default = mkPackage pkgs;
        inir = self.packages.${pkgs.system}.default;
      });

      nixosModules.default = mkNixosModule;
      nixosModules.inir = mkNixosModule;

      homeModules.default = mkHomeModule;
      homeModules.inir = mkHomeModule;

      # Conventional alias most Home Manager setups look for.
      homeManagerModules.default = mkHomeModule;
      homeManagerModules.inir = mkHomeModule;

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
