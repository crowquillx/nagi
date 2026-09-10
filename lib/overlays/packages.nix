# Package exposure and upstream overlay composition.
{ lib, inputs }:
let
  determinateNix = final: prev: {
    nix-direnv = prev.nix-direnv.override {
      nix = inputs.determinate-nix.packages.${final.stdenv.hostPlatform.system}.default;
    };
  };

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

  computerUseLinux = final: _prev: {
    computer-use-linux = final.callPackage ../../pkgs/computer-use-linux { };
  };
in
{
  inherit
    computerUseLinux
    determinateNix
    hushmic
    mo2Lint
    nixGaming
    vortex
    ;
}
