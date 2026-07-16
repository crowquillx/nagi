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
  mixedNiriPlasma =
    desktopEnabled
    && builtins.elem "niri" compositors
    && builtins.elem "plasma" compositors
    && get [ "features" "stylix" "enable" ] true
    && get [ "features" "theme" "qt" "enable" ] true;
in
{
  config = lib.mkIf mixedNiriPlasma {
    # Keep the generated qtct/Kvantum configuration for Niri, but leave the
    # login environment native to Plasma. Niri overrides these for its children.
    stylix.targets.qt.platform = lib.mkForce "qtct";
    home.sessionVariables = {
      QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
      QT_STYLE_OVERRIDE = lib.mkForce "breeze";
    };
    systemd.user.sessionVariables = {
      QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
      QT_STYLE_OVERRIDE = lib.mkForce "breeze";
    };
  };
}
