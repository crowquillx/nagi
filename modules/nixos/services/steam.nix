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
  cheatengineEnable = get [ "features" "gaming" "cheatengine" "enable" ] false;
  lutrisPkg = pkgs.lutris or null;
  heroicPkg = pkgs.heroic or null;
  protonPlusPkg = pkgs.protonplus or pkgs."protonup-qt" or null;
  winePkg =
    if pkgs ? wineWow64Packages && pkgs.wineWow64Packages ? wayland then
      pkgs.wineWow64Packages.wayland
    else
      pkgs.wine or null;
  winetricksPkg = pkgs.winetricks or null;
  protontricksPkg = pkgs.protontricks or null;
  bg3ModePkg = pkgs.writeShellApplication {
    name = "bg3-mode";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.procps
      protontricksPkg
    ];
    text = builtins.readFile ../../../scripts/bg3-mode;
  };
  vulkanToolsPkg = pkgs.vulkan-tools or null;
  pciutilsPkg = pkgs.pciutils or null;
  bottlesPkg = pkgs.bottles or null;
  cheatenginePkg = pkgs.cheatengine or null;
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
          assertion = !enabled || protontricksPkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'protontricks' could not be resolved.";
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
        {
          assertion = !cheatengineEnable || cheatenginePkg != null;
          message = "features.gaming.cheatengine.enable is true, but the 'cheatengine' package could not be resolved. Ensure the cheatengine-flake overlay is applied.";
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
        protontricksPkg
        bg3ModePkg
        vulkanToolsPkg
        pciutilsPkg
        bottlesPkg
      ] ++ lib.optionals cheatengineEnable [ cheatenginePkg ];
    })
    (lib.mkIf (enabled && cheatengineEnable) {
      # Grant Cheat Engine cap_sys_ptrace so it can scan and debug other
      # processes without lowering kernel.yama.ptrace_scope system-wide.
      # The wrapper copies the real ELF into /run/wrappers/bin with the file
      # capability set; the package's bin/cheatengine launcher execs this copy
      # after setting up LD_LIBRARY_PATH and cwd, so the capped process inherits
      # the full runtime env. Requires `switch` to materialize the wrapper.
      security.wrappers.cheatengine-bin = {
        source = "${cheatenginePkg}/opt/cheatengine/cheatengine-x86_64";
        capabilities = "cap_sys_ptrace+ep";
        owner = "root";
        group = "root";
        permissions = "u+rx,g+rx,o+rx";
      };
    })
  ];
}
