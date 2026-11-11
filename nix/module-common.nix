# What the NixOS and Home Manager modules share: the options and the inir.service unit, the same one setup installs
# on every distro (assets/systemd/inir.service), started by Niri.
{ lib, pkgs }:

{
  options = { commit, updateHint }: { config, ... }: {
    options.programs.inir = {
      enable = lib.mkEnableOption "iNiR, the desktop shell for Niri";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.callPackage ./package.nix {
          inherit pkgs commit updateHint;
          withWebEngine = config.programs.inir.webEngine;
        };
        defaultText = lib.literalExpression "inir.packages.\${system}.default";
        description = "The iNiR package. Its version is the base people run; hub items update themselves.";
      };

      webEngine = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Add Qt WebEngine to the shell's runtime, for the Web Apps tab of Material's sidebar (about 200 MB).";
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "More programs installed with iNiR, for the apps and commands your config names.";
      };

      service.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start iNiR with Niri through the inir user service.";
      };

      niriConfig.seed = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Copy iNiR's Niri config to ~/.config/niri before Niri first starts, when there is none yet.";
      };
    };
  };

  # setup copies defaults/niri on other distros; here once, writable, so Niri and the shell can still change it. Before
  # Niri's first start, or Niri writes its own config and opens its hotkey overlay over the welcome.
  niriSeed = package: pkgs.writeShellScript "inir-niri-seed" ''
    target="''${XDG_CONFIG_HOME:-$HOME/.config}/niri"
    [ -e "$target/config.kdl" ] && exit 0
    ${pkgs.coreutils}/bin/mkdir -p "$target"
    ${pkgs.coreutils}/bin/cp -r --no-preserve=mode ${package}/share/quickshell/inir/defaults/niri/. "$target/"
  '';

  # What an older package left in the person's home that would win over this one (leftovers.sh says what and why)
  leftovers = pkgs.writeShellScript "inir-leftovers" ''
    PATH=''${PATH:+$PATH:}${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.systemd ]}
    ${builtins.readFile ./leftovers.sh}
  '';

  # The unit as assets/systemd/inir.service states it; the first start after the package moves also brings the
  # person's copy in step with it (hub families included), so it is given longer than a plain start.
  service = cfg: {
    description = "iNiR shell";
    partOf = [ "niri.service" ];
    after = [ "niri.service" ];
    before = [ "xdg-desktop-autostart.target" ];
    environment = {
      QT_SCALE_FACTOR = "1";
      QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
      QT_LOGGING_RULES = "quickshell.dbus.properties=false;quickshell.dbus.objectmanager.warning=false;qt.qml.settings.warning=false;qt.core.qsettings.warning=false;kf.xmlgui=false;kf.coreaddons=false;kf.config.core=false;kf.iconthemes=false;qt.qpa.wayland.textinput.warning=false";
      QS_DISABLE_CRASH_HANDLER = "1";
    };
    startLimitIntervalSec = 30;
    startLimitBurst = 3;
    serviceConfig = {
      Type = "dbus";
      BusName = "org.kde.StatusNotifierWatcher";
      ExecStart = "${lib.getExe cfg.package} run --session";
      ExecStopPost = "-${lib.getExe cfg.package} cleanup-orphans";
      SuccessExitStatus = 143;
      KillMode = "process";
      KillSignal = "SIGTERM";
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStartSec = 300;
      TimeoutStopSec = 6;
      TimeoutStopFailureMode = "abort";
      LimitCORE = 0;
      LimitNOFILE = 65536;
      IOSchedulingPriority = 2;
    };
  };
}
