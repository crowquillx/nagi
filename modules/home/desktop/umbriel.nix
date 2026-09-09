{
  lib,
  vars ? { },
  options,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "hyprland";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasUmbriel = builtins.elem "umbriel" ([ compositor ] ++ extraCompositors);
in
{
  # The upstream module is imported only for hosts that install Umbriel. Keep
  # this module in the shared stack without introducing an unknown option on
  # hosts that do not import that module.
  config = lib.optionalAttrs (desktopEnabled && hasUmbriel && options.programs ? umbriel) {
    programs.umbriel.enable = true;
  };
}
