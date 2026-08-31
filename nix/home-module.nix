{ config, lib, pkgs, ... }:

let
  common = import ./module-common.nix { inherit lib pkgs; };
  cfg = config.programs.inir;
  finalPackage = common.resolvePackage cfg;
  wantedUnit = common.compositorUnit cfg.service.compositor;
  env = common.serviceEnvironment cfg // {
    PATH = lib.makeBinPath ([ finalPackage ] ++ cfg.extraPackages);
  };
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
    home.packages = [ finalPackage ];

    xdg.configFile = lib.mkIf cfg.configSymlink.enable {
      "quickshell/inir".source = "${finalPackage}/share/quickshell/inir";
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

      Install.WantedBy = lib.optional (wantedUnit != null) wantedUnit;
    };
  };
}
