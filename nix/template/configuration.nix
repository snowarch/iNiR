{ ... }:

{
  # Copy yours in: cp /etc/nixos/hardware-configuration.nix .
  imports = [ ./hardware-configuration.nix ];

  programs.inir = {
    enable = true;
    # Niri, a login screen, PipeWire, NetworkManager and the rest of a desktop session.
    desktop.enable = true;
    # they join the groups the shell's tools need (backlight, input, monitors, typing)
    users = [ "you" ];
  };

  users.users.you = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" ];
  };

  system.stateVersion = "25.11";
}
