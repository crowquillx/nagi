# Shared Stylix policy for NixOS and Home Manager consumers.
#
# Stylix stays enabled whenever features.stylix.enable is true, including
# Plasma-only hosts: app palettes (Ghostty, Kitty, browsers, CLI tools, ...)
# still need it. Plasma-only hosts skip targets Plasma already owns so
# Klassy, Breeze GTK, Plasma fonts, and the Rose Pine color scheme from
# features.stylix.variant keep the desktop chrome. Mixed hosts keep those
# targets for Niri/Hyprland (see modules/home/theme/qt.nix).
#
# Consumers must not set stylix.* options when enable is false: without
# Stylix enabled, its HM module may not be imported at all.
{
  lib,
  vars,
}:
let
  get = path: default: lib.attrByPath path default vars;
  compositors = [
    (get [ "desktop" "compositor" ] "hyprland")
  ]
  ++ get [ "desktop" "extraCompositors" ] [ ];
  hasPlasma = builtins.elem "plasma" compositors;
  hasStylixCompositor = builtins.any (
    c:
    builtins.elem c [
      "niri"
      "hyprland"
    ]
  ) compositors;
in
{
  enable = get [ "features" "stylix" "enable" ] true;
  plasmaOnly = hasPlasma && !hasStylixCompositor;

  # Surfaces Plasma already themes. kde is Home Manager only; NixOS
  # consumers must drop it before assigning stylix.targets.
  plasmaOwnedTargets = {
    fontconfig.enable = false;
    gnome.enable = false;
    gtk.enable = false;
    kde.enable = false;
    qt.enable = false;
  };
}
