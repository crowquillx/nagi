# Shared effective-Stylix predicate for NixOS and Home Manager consumers.
# Pure Plasma hosts skip Stylix: Plasma themes itself (Klassy, Breeze GTK,
# and the Rose Pine color scheme from features.stylix.variant).
# Mixed hosts keep Stylix so the Niri/Hyprland session stays themed
# (see modules/home/theme/qt.nix). Consumers must not set stylix.* options
# when this returns false: without Stylix enabled, its HM module may not be
# imported at all.
{
  lib,
  vars,
}:
let
  get = path: default: lib.attrByPath path default vars;
  compositors =
    [ (get [ "desktop" "compositor" ] "hyprland") ]
    ++ get [ "desktop" "extraCompositors" ] [ ];
  hasPlasma = builtins.elem "plasma" compositors;
  hasStylixCompositor = builtins.any (c: builtins.elem c [ "niri" "hyprland" ]) compositors;
in
get [ "features" "stylix" "enable" ] true && (!hasPlasma || hasStylixCompositor)
