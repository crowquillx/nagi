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
      packages.computerUseLinux
    ]
    ++ lib.optionals vars.features.gaming.steam.millennium.enable [
      inputs.millennium.overlays.default
    ]
    ++ lib.optionals vars.features.gaming.cheatengine.enable [
      inputs.cheatengine-flake.overlays.default
      compatibility.cheatengine
    ]
    ++ lib.optionals vars.features.gaming.enable [
      compatibility.hydraLauncher
      compatibility.patool
    ]
    ++ [ compatibility.llmAgents ]
    ++ lib.optionals vars.features.razer.openrazer.enable [
      compatibility.openrazerCer
    ]
    ++ lib.optionals vars.features.audio.arctis.enable [
      inputs.arctis-sound-manager.overlays.default
      compatibility.arctisWrapperArgs
    ];
in
{
  inherit sharedOverlays;
}
