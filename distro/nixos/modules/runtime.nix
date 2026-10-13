{ config, pkgs, lib, ... }:

let
  cfg = config.programs.inir;
in
{
  options.programs.inir = {
    intelPsrFix = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Fix screen flickering on Intel laptops (Gen 9-12) by disabling Panel Self Refresh (harmless no-op on non-Intel hardware).";
      };
    };

    nixLd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable nix-ld dynamic linker emulation for running unpatched binaries seamlessly.";
      };
    };
  };

  config = {
    nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];

    programs.nix-ld = lib.mkIf cfg.nixLd.enable {
      enable = lib.mkDefault true;
      libraries = lib.mkDefault (with pkgs; [
        stdenv.cc.cc.lib
        zlib
      ]);
    };

    environment.localBinInPath = lib.mkDefault true;

    boot.kernelParams = lib.mkIf cfg.intelPsrFix.enable [ "i915.enable_psr=0" ];

    environment.variables = {
      QML2_IMPORT_PATH = lib.makeSearchPath "lib/qt-6/qml" [
        pkgs.kdePackages.qt5compat
        (pkgs.kdePackages.kirigami.passthru.unwrapped or pkgs.kdePackages.kirigami)
        pkgs.kdePackages.qtmultimedia
        pkgs.kdePackages.syntax-highlighting
      ];

      QT_PLUGIN_PATH = lib.makeSearchPath "lib/qt-6/plugins" [
        pkgs.kdePackages.qtmultimedia
        pkgs.kdePackages.qt5compat
        pkgs.kdePackages.plasma-integration
        pkgs.darkly
      ];

      QT_QPA_PLATFORMTHEME = lib.mkDefault "qt6ct";
      QT_STYLE_OVERRIDE = lib.mkDefault "kvantum";
      QT_QPA_PLATFORM = lib.mkDefault "wayland;xcb";
    };
  };
}

