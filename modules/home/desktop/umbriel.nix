{
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
in
{
  # The upstream module is imported only for hosts that install Umbriel. Keep
  # this module in the shared stack without introducing an unknown option on
  # hosts that do not import that module.
  config = lib.optionalAttrs (desktopEnabled && hasUmbriel && options.programs ? umbriel) {
    programs.umbriel = {
      enable = true;
      settings = null;
    };
  };
}
