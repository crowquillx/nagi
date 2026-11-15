# Overlay assembly for resolved host variables.
{ lib, inputs }:
let
  packages = import ./overlays/packages.nix { inherit lib inputs; };
  compatibility = import ./overlays/compatibility.nix { inherit lib inputs; };

  sharedOverlays =
    vars:
    [
      packages.determinateNix
      packages.brave
      packages.hushmic
      packages.vortex
      packages.nixGaming
      packages.mo2Lint
      packages.computerUseLinux
      packages.multiosUsb
    ]
    ++ lib.optionals vars.features.chat.discord.equicord.enable [
      packages.equicord
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
      compatibility.lutrisGnomeDesktopRR
      compatibility.patool
      compatibility.rustyPathOfBuilding
    ]
    ++ [ compatibility.llmAgents ]
    ++ lib.optionals vars.features.mcp.nixos.enable [
      compatibility.mcpNixosMcp1
    ]
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
