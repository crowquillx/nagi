{ lib, pkgs, ... }:
let
  lixPackageSet = "stable";
in
{
  nix = {
    package = pkgs.lixPackageSets.${lixPackageSet}.lix;

    settings = {
      # Lix from nixpkgs is built and cached by the standard NixOS cache.
      substituters = lib.mkDefault [ "https://cache.nixos.org/" ];
      trusted-public-keys = lib.mkDefault [
        "cache.nixos.org-1:6NCHdD59X431o0gWmL9mpgVRm0xQ1A7d8P7hVh2R1Gk="
      ];
    };
  };

  nixpkgs.overlays = [
    (final: prev: {
      inherit (prev.lixPackageSets.${lixPackageSet})
        colmena
        nix-eval-jobs
        nix-fast-build
        nixpkgs-review
        ;
      nix-direnv = prev.nix-direnv.override {
        nix = final.lixPackageSets.${lixPackageSet}.lix;
      };
    })
  ];
}
