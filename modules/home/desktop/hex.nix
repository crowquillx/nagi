{
  config,
  lib,
  vars ? { },
  options,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  hexEnabled = desktopEnabled && get [ "desktop" "hex" "enable" ] false;
  keybind = get [ "desktop" "hex" "keybind" ] "Mod+Shift+D";
  hasUmbriel = get [ "desktop" "compositor" ] "umbriel" == "umbriel" && options.programs ? umbriel;
in
{
  config = lib.mkIf hexEnabled (
    lib.mkMerge [
      {
        programs.hex = {
          enable = true;
          autostart = true;
          # Downloads Hex's selected model once the network is up; never during activation.
          installModel = true;
          # A named card makes Hex open the raw ALSA device, which takes it from
          # PipeWire (and HushMic/Discord). Capture through PipeWire's default source.
          settings.microphone = "PipeWire Sound Server";
        };
      }
      # Umbriel offers no GlobalShortcuts portal, so bind Hex's CLI directly.
      # optionalAttrs keeps hosts without the Umbriel HM module from seeing the option.
      (lib.optionalAttrs hasUmbriel {
        programs.umbriel.settings.keybinds.${keybind} = {
          action = "spawn ${lib.getExe config.programs.hex.package} dictation toggle";
          repeat = false;
        };
      })
    ]
  );
}
