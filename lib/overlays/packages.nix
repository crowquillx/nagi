# Package exposure and upstream overlay composition.
{ lib, inputs }:
let
  determinateNix = final: prev: {
    nix-direnv = prev.nix-direnv.override {
      nix = inputs.determinate-nix.packages.${final.stdenv.hostPlatform.system}.default;
    };
  };

  # hyprland.cachix.org only serves packages built against upstream's pinned
  # nixpkgs. Upstream's overlays callPackage against the consumer tree and
  # always miss, so re-export the flake packages instead.
  hyprlandPackages =
    final: _prev:
    let
      packages = inputs.hyprland.packages.${final.stdenv.hostPlatform.system};
    in
    {
      inherit (packages) hyprland xdg-desktop-portal-hyprland;
    };

  hushmic = final: _prev: {
    hushmic = inputs.hushmic-nix.packages.${final.stdenv.hostPlatform.system}.default;
  };
  kwinEffectsBetterBlurDx = final: _prev: {
    kwin-effects-better-blur-dx =
      inputs.kwin-effects-better-blur-dx.packages.${final.stdenv.hostPlatform.system}.default;
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
in
{
  inherit
    determinateNix
    hushmic
    hyprlandPackages
    kwinEffectsBetterBlurDx
    mo2Lint
    nixGaming
    vortex
    ;
}
