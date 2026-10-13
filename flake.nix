{
  description = "iNiR desktop shell for Niri, packaged for NixOS and Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      }));
    in
    {
      # =======================================================================
      # Packages
      # =======================================================================
      packages = forAllSystems (pkgs:
        let
          inirDeps = import ./distro/nixos/modules/inir-deps.nix { inherit pkgs; };

          inirPatched = (pkgs.callPackage ./nix/package.nix { inherit pkgs; }).overrideAttrs (old: {
            # Adapt iNiR's Arch assumptions to NixOS. Regex-based and idempotent.
            postPatch = (old.postPatch or "") + ''
              cp ${./distro/nixos/nix/nixos-postpatch.py} nixos-postpatch.py
              python3 nixos-postpatch.py
              rm -f nixos-postpatch.py
            '';
            meta = (old.meta or { }) // {
              description = "Complete desktop shell for Niri built on Quickshell with Material You theming";
              homepage = "https://github.com/snowarch/inir";
              license = pkgs.lib.licenses.gpl3Only;
              mainProgram = "inir";
            };
          });

          mascotPackage = if builtins.pathExists ./nix/mascot-package.nix
            then pkgs.callPackage ./nix/mascot-package.nix { inherit pkgs; }
            else null;

          packageWithMascot = if mascotPackage != null
            then pkgs.symlinkJoin {
              name = "inir-with-mascot-${inirPatched.version or "2.33.0"}";
              paths = [ inirPatched mascotPackage ];
              meta = (inirPatched.meta or { }) // {
                description = "iNiR desktop shell with official Kira desktop mascot art pack integrated";
                homepage = "https://github.com/snowarch/inir";
                license = pkgs.lib.licenses.gpl3Only;
                mainProgram = "inir";
              };
            }
            else inirPatched;

          shellScript = name: description: path: extraPath:
            let
              script = pkgs.writeTextFile {
                inherit name;
                executable = true;
                destination = "/bin/${name}";
                text = "#!${pkgs.bash}/bin/bash\n" + builtins.readFile path;
              };
            in
            pkgs.runCommand name {
              nativeBuildInputs = [ pkgs.makeWrapper ];
              meta = {
                inherit description;
                homepage = "https://github.com/snowarch/inir";
                license = pkgs.lib.licenses.gpl3Only;
                mainProgram = name;
              };
            } ''
              makeWrapper ${script}/bin/${name} $out/bin/${name} \
                --prefix PATH : ${pkgs.lib.makeBinPath extraPath}
            '';

          niriSyncColors = shellScript "niri-sync-colors"
            "Dynamic Material You palette sync daemon for Niri focus rings, terminals, and GTK"
            ./distro/nixos/scripts/niri-sync-colors
            [
              pkgs.bash
              pkgs.coreutils
              pkgs.python3
              pkgs.glib
              pkgs.util-linux
              pkgs.inotify-tools
              pkgs.procps
              pkgs.jq
              pkgs.niri
            ];

          recordScreen = shellScript "record-screen"
            "Hardware-accelerated Wayland screen recorder with audio capture via wf-recorder and pactl"
            ./distro/nixos/scripts/record-screen
            [
              pkgs.bash
              pkgs.coreutils
              pkgs.wf-recorder
              pkgs.slurp
              pkgs.imagemagick
              pkgs.pulseaudio
              pkgs.procps
            ];

          verifySetup = shellScript "verify-setup"
            "Automated diagnostic sanity-checker for iNiR, Niri, and NixOS configuration"
            ./distro/nixos/scripts/verify-setup.sh
            [
              pkgs.bash
              pkgs.coreutils
              pkgs.systemd
            ];

          inirSync = shellScript "inir-sync"
            "Synchronization and diagnostic CLI tool for iNiR NixOS"
            ./distro/nixos/scripts/inir-sync
            [
              pkgs.bash
              pkgs.coreutils
              pkgs.git
              pkgs.jq
              pkgs.systemd
              pkgs.nix
            ];

          inirDepsEnv = pkgs.buildEnv {
            name = "inir-deps";
            paths = inirDeps;
            meta = {
              description = "Complete bundle of runtime dependencies for iNiR shell";
              homepage = "https://github.com/snowarch/inir";
              license = pkgs.lib.licenses.gpl3Only;
            };
          };
        in
        {
          default = inirPatched;
          inir = inirPatched;
          inir-mascot = mascotPackage;
          inir-with-mascot = packageWithMascot;
          niri-sync-colors = niriSyncColors;
          record-screen = recordScreen;
          verify-setup = verifySetup;
          inir-sync = inirSync;
          inir-deps = inirDepsEnv;
        });

      # =======================================================================
      # Apps (Run via: nix run .#<app>)
      # =======================================================================
      apps = forAllSystems (pkgs:
        let
          pkg = self.packages.${pkgs.system};
        in {
          default = {
            type = "app";
            program = "${pkg.inir}/bin/inir";
            meta.description = "iNiR desktop shell";
          };
          inir = {
            type = "app";
            program = "${pkg.inir}/bin/inir";
            meta.description = "iNiR desktop shell";
          };
          niri-sync-colors = {
            type = "app";
            program = "${pkg.niri-sync-colors}/bin/niri-sync-colors";
            meta.description = "Material You color palette sync daemon for Niri and terminals";
          };
          record-screen = {
            type = "app";
            program = "${pkg.record-screen}/bin/record-screen";
            meta.description = "Wayland screen and audio recorder";
          };
          verify-setup = {
            type = "app";
            program = "${pkg.verify-setup}/bin/verify-setup";
            meta.description = "Diagnostic sanity-checker for iNiR and Niri setup";
          };
          inir-sync = {
            type = "app";
            program = "${pkg.inir-sync}/bin/inir-sync";
            meta.description = "iNiR NixOS synchronization and diagnostic CLI";
          };
        });

      # =======================================================================
      # Development Shell (Run via: nix develop)
      # =======================================================================
      devShells = forAllSystems (pkgs:
        let
          inirDeps = import ./distro/nixos/modules/inir-deps.nix { inherit pkgs; };
        in {
          default = pkgs.mkShell {
            name = "inir-dev-shell";
            packages = inirDeps ++ (with pkgs; [
              nixpkgs-fmt
              git
            ]);
            shellHook = ''
              echo "❄️ Welcome to the iNiR NixOS development environment!"
            '';
          };
        });

      # =======================================================================
      # Formatter (Run via: nix fmt)
      # =======================================================================
      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);

      # =======================================================================
      # Starter Templates (Run via: nix flake init -t .#default)
      # =======================================================================
      templates = {
        default = {
          path = ./distro/nixos/templates/default;
          description = "Starter NixOS system configuration with iNiR desktop shell and Niri";
        };
        inir = {
          path = ./distro/nixos/templates/default;
          description = "Starter NixOS system configuration with iNiR desktop shell and Niri";
        };
      };

      # =======================================================================
      # Overlays
      # =======================================================================
      overlays.default = final: prev: {
        inir = self.packages.${final.system}.inir;
        inir-with-mascot = self.packages.${final.system}.inir-with-mascot;
        inir-mascot = self.packages.${final.system}.inir-mascot;
        niri-sync-colors = self.packages.${final.system}.niri-sync-colors;
        record-screen = self.packages.${final.system}.record-screen;
        verify-setup = self.packages.${final.system}.verify-setup;
        inir-sync = self.packages.${final.system}.inir-sync;
        inir-deps = self.packages.${final.system}.inir-deps;
      };

      # =======================================================================
      # NixOS Modules
      # =======================================================================
      nixosModules = {
        default = { ... }: {
          imports = [
            ./nix/nixos-module.nix
            ./distro/nixos/modules
          ];
          _module.args.inir = self;
        };

        inir = ./nix/nixos-module.nix;

        desktop = ./distro/nixos/modules/desktop.nix;
        audio = ./distro/nixos/modules/audio.nix;
        fonts = ./distro/nixos/modules/fonts.nix;
        mascot = ./distro/nixos/modules/mascot.nix;
        runtime = ./distro/nixos/modules/runtime.nix;
      };

      # =======================================================================
      # Home Manager Modules
      # =======================================================================
      homeModules = {
        default = ./distro/nixos/modules/home-manager.nix;
        inir = ./distro/nixos/modules/home-manager.nix;
        upstream = ./nix/home-module.nix;
      };


      # =======================================================================
      # Continuous Integration Checks
      # =======================================================================
      checks = forAllSystems (pkgs: {
        verify-setup = self.packages.${pkgs.system}.verify-setup;
        niri-sync-colors = self.packages.${pkgs.system}.niri-sync-colors;
        record-screen = self.packages.${pkgs.system}.record-screen;
        inir-sync = self.packages.${pkgs.system}.inir-sync;
      });
    };
}
