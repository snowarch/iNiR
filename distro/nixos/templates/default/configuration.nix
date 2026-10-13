# Configuration template for iNiR on NixOS
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Timezone and locale
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "es_MX.UTF-8";

  # Allow proprietary packages
  nixpkgs.config.allowUnfree = true;

  # Enable iNiR desktop shell and Niri compositor
  programs.inir = {
    enable = true;
    colorSync.enable = true;          # Material You color sync
    screenRecording.enable = true;    # Screen recorder with audio
    hardware.brightnessControl = true;# DDC/CI monitor brightness
    niri = {
      enable = true;
      autoDeployConfig = true;       # Auto-deploy Niri modular configs
    };
    audio.enable = true;
    desktop = {
      enable = true;
      displayManager = "gdm";
    };
  };

  # Primary user
  users.users."YOUR_USERNAME" = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "i2c" ];
  };

  system.stateVersion = "24.11";
}
