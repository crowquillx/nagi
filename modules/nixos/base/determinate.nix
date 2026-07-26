{ inputs, pkgs, ... }:
{
  determinate.enable = true;

  environment.systemPackages = [
    inputs.fh.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
