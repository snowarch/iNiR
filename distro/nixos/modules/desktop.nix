{ config, pkgs, lib, ... }:
let
  cfg = config.programs.inir.desktop;
in
{
  options.programs.inir.desktop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable a graphical login screen (display manager) out of the box.";
    };

    displayManager = lib.mkOption {
      type = lib.types.enum [ "gdm" "greetd" "sddm" ];
      default = "gdm";
      example = "sddm";
      description = ''
        Which display manager to use for the login screen:

        - "gdm" (default): GNOME Display Manager.
        - "greetd": minimal Wayland-first greeter (tuigreet).
        - "sddm": Simple Desktop Display Manager. Can be used together with
          the official ii-pixel theme from https://github.com/LATAR-web/inir-sddm-nixos.
      '';
    };

    enableGnomeFallback = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install and enable the GNOME desktop environment as an emergency fallback
        session (GDM only). Disabled by default to avoid downloading gigabytes of
        unused GNOME packages.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.displayManager == "gdm") {
      # Display manager (login screen)
      # Niri registers its own Wayland session automatically once programs.niri.enable is true.
      services.xserver.enable = lib.mkDefault true;
      services.displayManager.gdm.enable = lib.mkDefault true;
      services.desktopManager.gnome.enable = lib.mkDefault cfg.enableGnomeFallback;

      # Keyboard layout (defaults to user's existing settings if already defined)
      services.xserver.xkb = {
        layout = lib.mkDefault "us";
        variant = lib.mkDefault "";
      };
    })

    (lib.mkIf (cfg.enable && cfg.displayManager == "greetd") {
      # Wayland-first greeter: tuigreet lists every session in wayland-sessions,
      # so niri always shows up (fixes "niri missing from GDM", common in VMs).
      services.greetd = {
        enable = lib.mkDefault true;
        settings = {
          default_session = {
            command = "${pkgs.greetd.tuigreet or pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks";
            user = "greeter";
          };
        };
      };

      # Never run two display managers at once.
      services.displayManager.gdm.enable = lib.mkForce false;

      # Console keyboard fallback for TTY sessions
      console.keyMap = lib.mkDefault "us";
    })

    (lib.mkIf (cfg.enable && cfg.displayManager == "sddm") {
      services.displayManager.sddm = {
        enable = lib.mkDefault true;
        wayland.enable = lib.mkDefault true;
      };

      # Never run two display managers at once.
      services.displayManager.gdm.enable = lib.mkForce false;
      services.greetd.enable = lib.mkForce false;
    })
  ];
}
