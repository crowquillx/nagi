# Overlay assembly for resolved host variables.
{ lib, inputs }:
let
  packages = import ./overlays/packages.nix { inherit lib inputs; };
  compatibility = import ./overlays/compatibility.nix { inherit lib inputs; };

  sharedOverlays =
    vars:
    [
      packages.determinateNix
      packages.hushmic
      packages.vortex
      packages.nixGaming
      packages.mo2Lint
      packages.t3codeNightly
    ]
    ++ lib.optionals (packages.hyprland != null) [ packages.hyprland ]
    ++ lib.optionals (packages.hyprlandExtras != null) [ packages.hyprlandExtras ]
    ++ lib.optional vars.features.gaming.steam.millennium.enable inputs.millennium.overlays.default
    ++ lib.optionals vars.features.gaming.cheatengine.enable [
      inputs.cheatengine-flake.overlays.default
      compatibility.cheatengine
    ]
    ++ lib.optional vars.features.gaming.enable compatibility.patool
    ++ [ compatibility.llmAgents ];
in
{
  inherit sharedOverlays;
}
