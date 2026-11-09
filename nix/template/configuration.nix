{ ... }:

{
  # Copy yours in: cp /etc/nixos/hardware-configuration.nix .
  imports = [ ./hardware-configuration.nix ];

  # the boot loader nixos-generate-config writes on a UEFI machine; keep the lines of your own configuration.nix
  # if it boots another way (BIOS GRUB: boot.loader.grub.device)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  programs.inir = {
    enable = true;
    # Niri, a login screen, PipeWire, NetworkManager and the rest of a desktop session.
    desktop.enable = true;
    # they join the groups the shell's tools need (backlight, input, monitors, typing)
    users = [ "you" ];
  };

  users.users.you = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  system.stateVersion = "25.11";
}
