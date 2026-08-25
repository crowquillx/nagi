{
  lib,
  vars ? { },
  ...
}:
let
  stylixPolicy = import ../../theme/stylix-enabled.nix { inherit lib vars; };
in
{
  # The stylix key must be structurally absent when Stylix is inactive:
  # option paths are rejected even under `mkIf false`, and without Stylix
  # its HM module may not be imported at all. optionalAttrs forces the
  # predicate while constructing this module's config.
  #
  # gtk/qt/gnome/fontconfig also exist as NixOS targets
  # (modules/nixos/theme/stylix.nix); kde is Home Manager only.
  config = lib.optionalAttrs (stylixPolicy.enable && stylixPolicy.plasmaOnly) {
    stylix.targets = stylixPolicy.plasmaOwnedTargets;
  };
}
