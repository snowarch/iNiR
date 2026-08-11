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

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional (cfg.package != null) cfg.package;

    systemd.user.services.inir = lib.mkIf cfg.systemd.enable {
      description = "iNiR shell";
      wantedBy = lib.optional (cfg.systemd.wantedUnit != null) cfg.systemd.wantedUnit;
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      path = [ cfg.package ] ++ cfg.extraPackages;
      environment = {
        INIR_SYSTEM_RUNTIME_DIR = "${cfg.package}/share/quickshell/inir";
        INIR_FALLBACK_SYSTEM_RUNTIME_DIR = "${cfg.package}/share/quickshell/inir";
        QS_DISABLE_CRASH_HANDLER = "1";
        QT_LOGGING_RULES = "quickshell.dbus.properties=false;qt.qml.settings.warning=false;qt.core.qsettings.warning=false;kf.xmlgui=false;kf.coreaddons=false;kf.config.core=false;kf.iconthemes=false";
        QT_SCALE_FACTOR = "1";
        QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
      };
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
}
