{ config, lib, pkgs, ... }:

let
  common = import ./module-common.nix { inherit lib pkgs; };
  cfg = config.programs.inir;
  wantedUnit = common.compositorUnit cfg.service.compositor;

  # setup copies defaults/niri on other distros. Here it is copied once, writable, so Niri can still save to it.
  niriSeed = pkgs.writeShellScript "inir-niri-seed" ''
    target="''${XDG_CONFIG_HOME:-$HOME/.config}/niri"
    [ -e "$target/config.kdl" ] && exit 0
    mkdir -p "$target"
    cp -r --no-preserve=mode ${cfg.package}/share/quickshell/inir/defaults/niri/. "$target/"
  '';

  # The families the shell's styles ask for, not the whole Google Fonts tree.
  googleFonts = pkgs.google-fonts.override {
    fonts = [ "GoogleSansFlex" "RobotoFlex" "Gabarito" "ReadexPro" "SpaceGrotesk" ];
  };
in
{
  imports = [ common.optionsModule ];

  options.programs.inir = {
    niriConfig.seed = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Copy iNiR's Niri config to ~/.config/niri at login when there is none yet.";
    };
    fonts.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the fonts iNiR's styles use.";
    };
    desktop = {
      enable = lib.mkEnableOption "a complete Niri session for iNiR: Niri, a login screen, PipeWire, NetworkManager and UPower";
      displayManager = lib.mkOption {
        type = lib.types.enum [ "sddm" "greetd" "none" ];
        default = "sddm";
        description = "Login screen to enable with the desktop. `none` leaves it to the rest of your config.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ cfg.package ];

      systemd.user.services.inir = lib.mkIf cfg.service.enable {
        description = "iNiR shell";
        wantedBy = lib.optional (wantedUnit != null) wantedUnit;
        partOf = [ "niri.service" ];
        after = [ "niri.service" ];
        before = [ "xdg-desktop-autostart.target" ];
        path = [ cfg.package ] ++ cfg.extraPackages;
        environment = common.serviceEnvironment cfg;
        unitConfig = {
          Requisite = "niri.service";
          StartLimitIntervalSec = 30;
          StartLimitBurst = 3;
        };
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
          TimeoutStopSec = 15;
          LimitCORE = 0;
          IOSchedulingPriority = 2;
        };
      };
    }

    (lib.mkIf cfg.niriConfig.seed {
      systemd.user.services.inir-niri-seed = {
        description = "Copy iNiR's Niri config on first login";
        wantedBy = [ "default.target" ];
        before = [ "niri.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = niriSeed;
        };
      };
    })

    (lib.mkIf cfg.fonts.enable {
      fonts.packages = [
        pkgs.material-symbols
        pkgs.nerd-fonts.jetbrains-mono
        pkgs.noto-fonts
        pkgs.noto-fonts-color-emoji
        googleFonts
      ];
    })

    (lib.mkIf cfg.desktop.enable {
      # The niri module brings the portals, polkit, the keyring and the session file.
      programs.niri.enable = lib.mkDefault true;
      security.rtkit.enable = lib.mkDefault true;
      services.pipewire = {
        enable = lib.mkDefault true;
        alsa.enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
        wireplumber.enable = lib.mkDefault true;
      };
      networking.networkmanager.enable = lib.mkDefault true;
      services.upower.enable = lib.mkDefault true;
      services.displayManager.sddm = lib.mkIf (cfg.desktop.displayManager == "sddm") {
        enable = lib.mkDefault true;
        wayland.enable = lib.mkDefault true;
      };
      services.greetd = lib.mkIf (cfg.desktop.displayManager == "greetd") {
        enable = lib.mkDefault true;
        settings.default_session.command = lib.mkDefault "${lib.getExe pkgs.tuigreet} --time --remember --cmd niri-session";
      };
    })
  ]);
}
