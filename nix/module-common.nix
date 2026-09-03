{ lib, pkgs }:

let
  defaultPackage = pkgs.callPackage ./package.nix { inherit pkgs; };
  mascotPackage = pkgs.callPackage ./mascot-package.nix { inherit pkgs; };

  # Mirror the flake's packages.<system>.inir-with-mascot output: a symlinkJoin
  # of the shell runtime and the optional mascot art pack. Kept here so the
  # module can produce the same combined package when mascot.enable is set.
  packageWithMascot = cfg:
    pkgs.symlinkJoin {
      name = "inir-with-mascot-${cfg.package.version}";
      paths = [ cfg.package mascotPackage ];
    };

  # Return the package the service should actually run. When mascot.enable is
  # on, swap in the combined package so sprites are present in the packaged
  # runtime tree (which is read-only, so they must be baked in at build time).
  resolvePackage = cfg:
    if cfg.mascot.enable then packageWithMascot cfg else cfg.package;
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

      mascot = lib.mkEnableOption "bundled mascot art pack" // {
        description = "Run the shell with the inir-mascot art pack (354 poses/animations). When enabled, the configured package is combined with the mascot companion package so sprites are present in the read-only packaged runtime tree with no runtime download.";
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

  inherit resolvePackage;

  serviceEnvironment = cfg:
    let
      pkg = resolvePackage cfg;
    in
    {
      INIR_SYSTEM_RUNTIME_DIR = "${pkg}/share/quickshell/inir";
      INIR_FALLBACK_SYSTEM_RUNTIME_DIR = "${pkg}/share/quickshell/inir";
      QS_DISABLE_CRASH_HANDLER = "1";
      QT_LOGGING_RULES = "quickshell.dbus.properties=false;qt.qml.settings.warning=false;qt.core.qsettings.warning=false;kf.xmlgui=false;kf.coreaddons=false;kf.config.core=false;kf.iconthemes=false";
      QT_SCALE_FACTOR = "1";
      QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
    };
}
