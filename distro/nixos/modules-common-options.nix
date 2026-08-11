{ lib, ... }:
{
  imports = [
    # systemd.enable is consistent with option names of other NixOS modules
    (lib.modules.mkRenamedOptionModule
      [ "programs" "inir" "service" "enable" ]
      [ "programs" "inir" "systemd" "enable" ]
    )
    # An option for a unit name is more flexible than the enum that programs.inir.service.compositor
    # accepted. For example, the compositor could use a different unit name not accounted for by the
    # enum.
    (lib.modules.mkRemovedOptionModule [ "programs" "inir" "service" "compositor" ] ''
      Use programs.inir.systemd.wantedUnit instead, which can be set to a specific unit name.
    '')
  ];

  options.programs.inir = {
    enable = lib.options.mkEnableOption "iNiR desktop shell";

    package = lib.options.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The iNiR package to install.";
    };

    extraPackages = lib.options.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra runtime packages made available to the iNiR service.";
    };

    systemd = {
      enable = lib.options.mkEnableOption "the systemd user service for iNiR" // {
        default = true;
      };

      wantedUnit = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "niri.service";
        example = "wayland-wm@Hyprland.service";
        description = "Compositor user unit that should want inir.service. Set null to create the unit without auto-start wiring.";
      };
    };
  };
}
