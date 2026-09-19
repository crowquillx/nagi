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
  compositor = get [ "desktop" "compositor" ] "umbriel";
  hasUmbriel = compositor == "umbriel";
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
    programs.umbriel = {
      enable = true;
      settings = mergedSettings // {
        window_rule = commonSettings.window_rule ++ hostWindowRules;
      };
    };
  };
}
