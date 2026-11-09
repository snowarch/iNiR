# iNiR on NixOS: what setup does as root on Arch (packages, services, groups, the login screen), declared here; what
# it does as the person (their copy of the shell, the families, their config) the shell's own setup still does, at
# the first start after the package moves (`inir run`, package.nix).
{ commit ? "unknown" }:
{ config, lib, pkgs, ... }:

let
  common = import ./module-common.nix { inherit lib pkgs; };
  cfg = config.programs.inir;
  deps = cfg.package.passthru.deps;

  # setup copies defaults/niri on other distros; here once, writable, so Niri and the shell can still change it
  niriSeed = pkgs.writeShellScript "inir-niri-seed" ''
    target="''${XDG_CONFIG_HOME:-$HOME/.config}/niri"
    [ -e "$target/config.kdl" ] && exit 0
    mkdir -p "$target"
    cp -r --no-preserve=mode ${cfg.package}/share/quickshell/inir/defaults/niri/. "$target/"
  '';

  sddmTheme = pkgs.callPackage ./sddm-theme.nix { inherit pkgs; background = cfg.desktop.loginBackground; };
in
{
  imports = [ (common.options { inherit commit; updateHint = "nix flake update inir, then nixos-rebuild switch"; }) ];

  options.programs.inir = {
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = "People who use iNiR: they join the groups setup adds on other distros (video, input, i2c, ydotool).";
    };
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
      enable = lib.mkEnableOption "a complete Niri session for iNiR: Niri, a login screen, PipeWire, NetworkManager, Bluetooth and the rest setup turns on elsewhere";
      displayManager = lib.mkOption {
        type = lib.types.enum [ "sddm" "greetd" "none" ];
        default = "sddm";
        description = "Login screen. `sddm` wears iNiR's ii-pixel theme; `none` leaves it to the rest of your config.";
      };
      loginBackground = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "A picture for the login screen (the shell cannot write its wallpaper into the store).";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ cfg.package ] ++ cfg.package.passthru.runtimeDependencies ++ cfg.extraPackages;

      systemd.user.services.inir = lib.mkIf cfg.service.enable (common.service cfg // {
        wantedBy = [ "niri.service" ];
      });

      # what the shell's surfaces stand on, as setup sets it up on Arch
      programs.dconf.enable = lib.mkDefault true;
      programs.fish.enable = lib.mkDefault true;
      programs.ydotool.enable = lib.mkDefault true;
      hardware.i2c.enable = lib.mkDefault true;
      security.polkit.enable = true;
      security.pam.services.swaylock = { };
      services.upower.enable = lib.mkDefault true;
      services.power-profiles-daemon.enable = lib.mkDefault true;
      services.geoclue2.enable = lib.mkDefault true;
      services.gnome.gnome-keyring.enable = lib.mkDefault true;
      services.udev.packages = [ pkgs.brightnessctl ];
      xdg.portal = {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-gnome ];
      };
      # Qt apps take the shell's colours through KDE's platform theme (setup writes QT_QPA_PLATFORMTHEME=kde)
      qt = {
        enable = lib.mkDefault true;
        platformTheme = lib.mkDefault "kde";
      };

      # before inir.service starts, at every login and switch: what an older package left would win over this one
      system.userActivationScripts.inir-leftovers = "${common.leftovers}";

      users.users = lib.genAttrs cfg.users (_: {
        extraGroups = [ "video" "input" "i2c" "ydotool" ];
      });
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
      fonts.packages = deps.fonts;
    })

    (lib.mkIf cfg.desktop.enable {
      # the niri module brings its portal, polkit, the keyring and the session file
      programs.niri.enable = lib.mkDefault true;
      security.rtkit.enable = lib.mkDefault true;
      services.pipewire = {
        enable = lib.mkDefault true;
        alsa.enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
        wireplumber.enable = lib.mkDefault true;
      };
      networking.networkmanager.enable = lib.mkDefault true;
      hardware.bluetooth.enable = lib.mkDefault true;
      services.blueman.enable = lib.mkDefault true;
      services.displayManager.sddm = lib.mkIf (cfg.desktop.displayManager == "sddm") {
        enable = lib.mkDefault true;
        wayland.enable = lib.mkDefault true;
        theme = lib.mkDefault "ii-pixel";
        extraPackages = with pkgs.kdePackages; [ qt5compat qtsvg qtdeclarative ];
      };
      environment.systemPackages = lib.optional (cfg.desktop.displayManager == "sddm") sddmTheme;
      services.greetd = lib.mkIf (cfg.desktop.displayManager == "greetd") {
        enable = lib.mkDefault true;
        settings.default_session.command = lib.mkDefault "${lib.getExe pkgs.tuigreet} --time --remember --cmd niri-session";
      };
    })
  ]);
}
