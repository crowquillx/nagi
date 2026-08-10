{ lib, config, ... }:
let
  enabled = config.nagi.variables.features.audio.enable;
in
{
  config = lib.mkIf enabled {
    services.pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      wireplumber.enable = true;
    };

    services.pulseaudio.enable = false;
  };
}
