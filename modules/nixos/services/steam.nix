{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "gaming" "enable" ] false;
  gamescopeSessionEnable = get [ "features" "gaming" "steam" "gamescopeSession" "enable" ] false;
  remotePlayOpenFirewall = get [ "features" "gaming" "steam" "remotePlay" "openFirewall" ] true;
  dedicatedServerOpenFirewall = get [
    "features"
    "gaming"
    "steam"
    "dedicatedServer"
    "openFirewall"
  ] true;
  localTransfersOpenFirewall = get [
    "features"
    "gaming"
    "steam"
    "localNetworkGameTransfers"
    "openFirewall"
  ] true;
  millenniumEnable = get [ "features" "gaming" "steam" "millennium" "enable" ] false;
  lutrisPkg = pkgs.lutris or null;
  heroicPkg = pkgs.heroic or null;
  protonPlusPkg = pkgs.protonplus or pkgs."protonup-qt" or null;
  winePkg =
    if pkgs ? wineWow64Packages && pkgs.wineWow64Packages ? wayland then
      pkgs.wineWow64Packages.wayland
    else
      pkgs.wine or null;
  winetricksPkg = pkgs.winetricks or null;
  vulkanToolsPkg = pkgs.vulkan-tools or null;
  pciutilsPkg = pkgs.pciutils or null;
  bottlesPkg = pkgs.bottles or null;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !enabled || lutrisPkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'lutris' could not be resolved.";
        }
        {
          assertion = !enabled || heroicPkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'heroic' could not be resolved.";
        }
        {
          assertion = !enabled || protonPlusPkg != null;
          message = "features.gaming.enable is true, but neither 'protonplus' nor fallback 'protonup-qt' could be resolved.";
        }
        {
          assertion = !enabled || winePkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'wineWow64Packages.wayland' (or fallback 'wine') could not be resolved.";
        }
        {
          assertion = !enabled || winetricksPkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'winetricks' could not be resolved.";
        }
        {
          assertion = !enabled || vulkanToolsPkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'vulkan-tools' could not be resolved.";
        }
        {
          assertion = !enabled || pciutilsPkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'pciutils' could not be resolved.";
        }
        {
          assertion = !enabled || bottlesPkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'bottles' could not be resolved.";
        }
      ];
    }
    (lib.mkIf enabled {
      programs.steam = {
        enable = true;
        package = lib.mkIf millenniumEnable pkgs.millennium-steam;
        gamescopeSession.enable = gamescopeSessionEnable;
        remotePlay.openFirewall = remotePlayOpenFirewall;
        dedicatedServer.openFirewall = dedicatedServerOpenFirewall;
        localNetworkGameTransfers.openFirewall = localTransfersOpenFirewall;
      };

      environment.systemPackages = [
        lutrisPkg
        heroicPkg
        protonPlusPkg
        winePkg
        winetricksPkg
        vulkanToolsPkg
        pciutilsPkg
        bottlesPkg
      ];
    })
  ];
}
