{
  lib,
  config,
  pkgs,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
in
{
  imports = [
    ../common/default.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = get [ "host" "name" ] "tanlappy";

  # Avoid Lix's random-only temporary paths on this RDRAND-affected Ryzen 3500U.
  nix.package = lib.mkForce pkgs.nixVersions.latest;
}
