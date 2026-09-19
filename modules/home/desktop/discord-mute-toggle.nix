{
  lib,
  pkgs,
  vars ? { },
  options,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  cfg = get [ "features" "chat" "discord" "mouseMute" ] {
    enable = false;
    device = null;
    button = 276;
  };
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "umbriel";
  chatClient = get [ "features" "chat" "client" ] "none";
  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  helper = pkgs.writeShellApplication {
    name = "nagi-discord-mute-toggle";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      exec ${python}/bin/python3 -u ${./discord-mute-toggle.py} \
        --device ${lib.escapeShellArg cfg.device} --button ${toString cfg.button} "$@"
    '';
  };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || (desktopEnabled && compositor == "umbriel" && chatClient == "discord");
          message = "features.chat.discord.mouseMute requires the Discord client and an Umbriel desktop.";
        }
        {
          assertion = !cfg.enable || cfg.device != null;
          message = "features.chat.discord.mouseMute.device must identify the mouse event device when enabled.";
        }
      ];
    }
    (lib.optionalAttrs (cfg.enable && cfg.device != null && options.programs ? umbriel) {
      home.packages = [ helper ];
      programs.umbriel.settings.general.autostart = lib.mkAfter [ (lib.getExe helper) ];
    })
  ];
}
