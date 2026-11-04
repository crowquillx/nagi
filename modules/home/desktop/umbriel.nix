{
  config,
  lib,
  pkgs,
  vars ? { },
  options,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "umbriel";
  hasUmbriel = compositor == "umbriel";
  xwaylandPrimaryOutput = get [ "desktop" "umbriel" "xwaylandPrimaryOutput" ] null;
  xwaylandPrimaryHelper = pkgs.writeShellApplication {
    name = "nagi-xwayland-primary-output";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.xrandr
    ];
    text = ''
      output=${lib.escapeShellArg xwaylandPrimaryOutput}
      for ((attempt = 0; attempt < 30; attempt++)); do
        if xrandr --query 2>/dev/null | awk -v output="$output" '
          $1 == output && $2 == "connected" {
            mode = $3 == "primary" ? $4 : $3
            if (mode ~ /^[0-9]+x[0-9]+[+-]/) found = 1
          }
          END { exit !found }
        '; then
          exec xrandr --output "$output" --primary
        fi
        sleep 1
      done
      echo "Xwayland output $output was not ready within 30 seconds" >&2
      exit 1
    '';
  };
  hostSettings = get [ "desktop" "umbriel" "settings" ] { };
  hostWindowRules = hostSettings.window_rule or [ ];
  commonSettings = import ./umbriel-settings.nix;
  commonSettingsWithPaths = commonSettings // {
    environment = commonSettings.environment // {
      NOCTALIA_CONFIG_HOME = "${config.xdg.configHome}/umbriel/shell-config";
      NOCTALIA_STATE_HOME = "${config.xdg.configHome}/umbriel/shell-state";
    };
  };
  mergedSettings = lib.recursiveUpdate commonSettingsWithPaths (
    builtins.removeAttrs hostSettings [ "window_rule" ]
  );
in
{
  # The upstream module is imported only for hosts that install Umbriel. Keep
  # this module in the shared stack without introducing an unknown option on
  # hosts that do not import that module.
  config = lib.optionalAttrs (desktopEnabled && hasUmbriel && options.programs ? umbriel) {
    home.packages = lib.optionals (xwaylandPrimaryOutput != null) [
      pkgs.xrandr
      xwaylandPrimaryHelper
    ];
    programs.umbriel = {
      enable = true;
      settings = mergedSettings // {
        general = mergedSettings.general // {
          autostart =
            mergedSettings.general.autostart
            ++ lib.optional (xwaylandPrimaryOutput != null) (lib.getExe xwaylandPrimaryHelper);
        };
        window_rule = commonSettings.window_rule ++ hostWindowRules;
      };
    };
  };
}
