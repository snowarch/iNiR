{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.inir;
in
{
  imports = [ ./modules-common-options.nix ];

  options.programs.inir.configSymlink = {
    enable = lib.options.mkEnableOption "creating a symlink to the quickshell config for tools that expect the traditional path";
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    xdg.configFile = lib.mkIf cfg.configSymlink.enable {
      "quickshell/inir".source = "${cfg.package}/share/quickshell/inir";
    };

    systemd.user.services.inir = lib.mkIf cfg.systemd.enable {
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
        Environment = ''
          INIR_SYSTEM_RUNTIME_DIR=${cfg.package}/share/quickshell/inir
          INIR_FALLBACK_SYSTEM_RUNTIME_DIR=${cfg.package}/share/quickshell/inir
          QS_DISABLE_CRASH_HANDLER=1
          QT_LOGGING_RULES=quickshell.dbus.properties=false;qt.qml.settings.warning=false;qt.core.qsettings.warning=false;kf.xmlgui=false;kf.coreaddons=false;kf.config.core=false;kf.iconthemes=false
          QT_SCALE_FACTOR=1
          QT_SCALE_FACTOR_ROUNDING_POLICY=RoundPreferFloor
        '';
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

      Install.WantedBy = lib.optional (cfg.systemd.wantedUnit != null) cfg.systemd.wantedUnit;
    };
  };
}
