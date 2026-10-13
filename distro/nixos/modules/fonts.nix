{ config, pkgs, lib, ... }:

let
  cfg = config.programs.inir.fonts;
in
{
  options.programs.inir.fonts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install fonts required by iNiR UI, icons, and shell widgets (Material Symbols, JetBrains Mono Nerd Font, Roboto Flex).";
    };
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = lib.mkDefault (with pkgs; [
      nerd-fonts.jetbrains-mono
      roboto-flex
      google-fonts
      twitter-color-emoji
      material-symbols
    ]);

    fonts.fontconfig.enable = lib.mkDefault true;
  };
}

