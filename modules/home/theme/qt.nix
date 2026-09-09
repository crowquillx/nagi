{
  lib,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  compositors = [ compositor ] ++ extraCompositors;
  mixedWaylandPlasma =
    desktopEnabled
    && builtins.any (
      c:
      builtins.elem c [
        "niri"
        "hyprland"
        "umbriel"
      ]
    ) compositors
    && builtins.elem "plasma" compositors
    && get [ "features" "stylix" "enable" ] true
    && get [ "features" "theme" "qt" "enable" ] true;
in
{
  # The stylix key must be structurally absent when mixedWaylandPlasma is false:
  # option paths are rejected even under `mkIf false`, and without Stylix its
  # HM module may not be imported at all. optionalAttrs forces the predicate
  # while constructing this module's config.
  config = {
    # Keep the generated qtct/Kvantum configuration for Wayland compositors, but leave the
    # login environment native to Plasma. Niri overrides these for its children.
    home.sessionVariables = lib.mkIf mixedWaylandPlasma {
      QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
      QT_STYLE_OVERRIDE = lib.mkForce "breeze";
    };
    systemd.user.sessionVariables = lib.mkIf mixedWaylandPlasma {
      QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
      QT_STYLE_OVERRIDE = lib.mkForce "breeze";
    };
  }
  // lib.optionalAttrs mixedWaylandPlasma {
    stylix.targets.qt.platform = lib.mkForce "qtct";
  };
}
