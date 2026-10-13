{ config, lib, ... }:
let
  cfg = config.programs.inir.audio;
in
{
  options.programs.inir.audio = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable PipeWire audio stack required for iNiR volume and media player widgets.";
    };
  };

  config = lib.mkIf cfg.enable {
    # PipeWire is needed for iNiR's top-bar volume sliders, output device selectors,
    # mute toggles, and MPRIS playerctl media integration.
    # All settings use lib.mkDefault to seamlessly adapt to any existing user audio config.
    services.pulseaudio.enable = lib.mkDefault false;
    security.rtkit.enable = lib.mkDefault true;
    services.pipewire = {
      enable = lib.mkDefault true;
      alsa.enable = lib.mkDefault true;
      alsa.support32Bit = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
      wireplumber.enable = lib.mkDefault true;
    };
  };
}
