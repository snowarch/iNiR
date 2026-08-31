{ config, lib, pkgs, ... }:

let
  common = import ./module-common.nix { inherit lib pkgs; };
  cfg = config.programs.inir;
  finalPackage = common.resolvePackage cfg;
  wantedUnit = common.compositorUnit cfg.service.compositor;
in
{
  imports = [ common.optionsModule ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ finalPackage ];

    systemd.user.services.inir = lib.mkIf cfg.service.enable {
      description = "iNiR shell";
      wantedBy = lib.optional (wantedUnit != null) wantedUnit;
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      path = [ finalPackage ] ++ cfg.extraPackages;
      environment = common.serviceEnvironment cfg;
      unitConfig = {
        Requisite = "graphical-session.target";
        StartLimitIntervalSec = 30;
        StartLimitBurst = 3;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe finalPackage} run --session";
        ExecStopPost = "-${lib.getExe finalPackage} cleanup-orphans";
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
}
