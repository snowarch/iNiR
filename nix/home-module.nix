# iNiR through Home Manager: the package, its programs and fonts for this person, and the inir.service unit Niri
# starts. What needs root (Niri itself, PipeWire, NetworkManager, Bluetooth, UPower, power profiles, the login screen,
# groups) belongs to the system: the NixOS module, or your distro's packages.
{ commit ? "unknown" }:
{ config, lib, pkgs, ... }:

let
  common = import ./module-common.nix { inherit lib pkgs; };
  cfg = config.programs.inir;
  unit = common.service cfg;
  value = v: if builtins.isBool v then lib.boolToString v else toString v;
in
{
  imports = [ (common.options { inherit commit; updateHint = "nix flake update inir, then home-manager switch"; }) ];

  options.programs.inir.fonts.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install the fonts iNiR's styles use.";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ] ++ cfg.package.passthru.runtimeDependencies ++ cfg.extraPackages
      ++ lib.optionals cfg.fonts.enable cfg.package.passthru.deps.fonts;
    fonts.fontconfig.enable = lib.mkIf cfg.fonts.enable true;

    # before Home Manager checks its links: an older package's launcher and unit would be in their way
    home.activation.inirLeftovers = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      run ${common.leftovers}
    '';
    # at every switch and at boot, so before the first login; after Home Manager links its own files (a Niri config it
    # manages stays)
    home.activation.inirNiriSeed = lib.mkIf cfg.niriConfig.seed (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${common.niriSeed cfg.package}
    '');

    systemd.user.services.inir = lib.mkIf cfg.service.enable {
      Unit = {
        Description = unit.description;
        PartOf = unit.partOf;
        After = unit.after;
        Before = unit.before;
        StartLimitIntervalSec = unit.startLimitIntervalSec;
        StartLimitBurst = unit.startLimitBurst;
      };
      Service = lib.mapAttrs (_: value) unit.serviceConfig // {
        Environment = lib.mapAttrsToList (name: v: "${name}=${v}") unit.environment;
      };
      Install.WantedBy = [ "niri.service" ];
    };
  };
}
