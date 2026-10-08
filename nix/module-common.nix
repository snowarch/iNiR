{ lib, pkgs }:

let
  defaultPackage = pkgs.callPackage ./package.nix { inherit pkgs; };
in
{
  optionsModule = { config, ... }: {
    options.programs.inir = {
      enable = lib.mkEnableOption "iNiR desktop shell";

      package = lib.mkOption {
        type = lib.types.package;
        default = defaultPackage;
        defaultText = lib.literalExpression "pkgs.callPackage ./nix/package.nix { inherit pkgs; }";
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
          type = lib.types.nullOr (lib.types.enum [ "niri" ]);
          default = "niri";
          description = "Niri user unit wiring for inir.service. Set null to create the unit without auto-start wiring.";
        };
      };
    };
  };

  compositorUnit = compositor:
    if compositor == "niri" then "niri.service"
    else null;

  serviceEnvironment = cfg: {
    INIR_SYSTEM_RUNTIME_DIR = "${cfg.package}/share/quickshell/inir";
    INIR_FALLBACK_SYSTEM_RUNTIME_DIR = "${cfg.package}/share/quickshell/inir";
    QS_DISABLE_CRASH_HANDLER = "1";
    QT_LOGGING_RULES = "quickshell.dbus.properties=false;qt.qml.settings.warning=false;qt.core.qsettings.warning=false;kf.xmlgui=false;kf.coreaddons=false;kf.config.core=false;kf.iconthemes=false";
    QT_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
  };
}
