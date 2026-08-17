# Package exposure and upstream overlay composition.
{ lib, inputs }:
let
  determinateNix = final: prev: {
    nix-direnv = prev.nix-direnv.override {
      nix = inputs.determinate-nix.packages.${final.stdenv.hostPlatform.system}.default;
    };
  };

  hyprland = lib.attrByPath [ "hyprland" "overlays" "hyprland-packages" ] null inputs;
  hyprlandExtras = lib.attrByPath [ "hyprland" "overlays" "hyprland-extras" ] null inputs;

  hushmic = final: _prev: {
    hushmic = inputs.hushmic-nix.packages.${final.stdenv.hostPlatform.system}.default;
  };
  vortex = final: _prev: {
    vortex = inputs.vortex-nix.packages.${final.stdenv.hostPlatform.system}.vortex;
  };

  # Prefer flake packages over nix-gaming's overlay so these stay compatible
  # with the upstream pin and binary cache.
  nixGaming =
    final: _prev:
    let
      packages = inputs.nix-gaming.packages.${final.stdenv.hostPlatform.system};
    in
    {
      inherit (packages) osu-lazer-bin;
    };

  mo2Lint = final: _prev: {
    mo2-lint = final.callPackage ../../pkgs/mo2-lint { };
  };
  # Keep the local nightly AppImage. llm-agents.nix packages t3code from
  # source at the last stable tag (0.0.33) and wraps the stock grok
  # bubblewrap launcher, which fails when T3 starts `grok agent stdio`.
  t3codeNightly = final: _prev: {
    t3code = final.callPackage ../../pkgs/t3code-nightly { };
  };
in
{
  inherit
    determinateNix
    hushmic
    hyprland
    hyprlandExtras
    mo2Lint
    nixGaming
    t3codeNightly
    vortex
    ;
}
