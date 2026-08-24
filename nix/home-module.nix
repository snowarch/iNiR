{ config, lib, pkgs, ... }:

let
  common = import ./module-common.nix { inherit lib pkgs; };
  cfg = config.programs.inir;
  wantedUnit = common.compositorUnit cfg.service.compositor;
  env = common.serviceEnvironment cfg;
in
{
  imports = [ common.optionsModule ];

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
}
