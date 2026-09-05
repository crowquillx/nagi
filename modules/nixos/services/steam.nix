{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  gaming = v.features.gaming;
  enabled = gaming.enable;
  gamescopeSessionEnable = gaming.steam.gamescopeSession.enable;
  remotePlayOpenFirewall = gaming.steam.remotePlay.openFirewall;
  dedicatedServerOpenFirewall = gaming.steam.dedicatedServer.openFirewall;
  localTransfersOpenFirewall = gaming.steam.localNetworkGameTransfers.openFirewall;
  millenniumEnable = gaming.steam.millennium.enable;
  cursorTheme = import ../../theme/cursor-theme.nix;
  cursorPackage = lib.attrByPath [ cursorTheme.packageAttr ] null pkgs;
  gamemodeEnable = gaming.gamemode.enable;
  cheatengineEnable = gaming.cheatengine.enable;
  pcsx2Enable = gaming.pcsx2.enable;
  godotEnable = gaming.godot.enable;
  primaryUser = v.users.primary;
  cheatengineGroup = "cheatengine";
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
  pcsx2Pkg = pkgs.pcsx2 or null;
  godotPkg = pkgs.godot or null;
  mo2LintPkg = pkgs.mo2-lint or null;
  rustyPathOfBuildingPkg = pkgs.rusty-path-of-building or null;
  awakenedPoeTradeBase = pkgs.awakened-poe-trade or null;
  # Preserve APT's bundled Electron: the nixpkgs replacement is less reliable
  # for its XWayland global hotkey and synthesized clipboard input path.
  awakenedPoeTradeAppImage =
    if awakenedPoeTradeBase == null then
      null
    else
      pkgs.appimageTools.wrapType2 {
        pname = "awakened-poe-trade";
        inherit (awakenedPoeTradeBase) version src meta;
        extraInstallCommands = ''
          install -m 444 -D \
            ${awakenedPoeTradeBase.passthru.appImageContents}/awakened-poe-trade.desktop \
            "$out/share/applications/awakened-poe-trade.desktop"
          substituteInPlace "$out/share/applications/awakened-poe-trade.desktop" \
            --replace-fail 'Exec=AppRun' 'Exec=awakened-poe-trade'
          cp -r ${awakenedPoeTradeBase.passthru.appImageContents}/usr/share/icons "$out/share/"
        '';
      };
  awakenedPoeTradePkg =
    if awakenedPoeTradeAppImage == null then
      null
    else
      pkgs.symlinkJoin {
        name = "awakened-poe-trade-x11";
        paths = [ awakenedPoeTradeAppImage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm -f "$out/bin/awakened-poe-trade"
          makeWrapper "${awakenedPoeTradeAppImage}/bin/awakened-poe-trade" "$out/bin/awakened-poe-trade" \
            --unset NIXOS_OZONE_WL \
            --unset ELECTRON_OZONE_PLATFORM_HINT \
            --set XDG_SESSION_TYPE x11 \
            --set GDK_BACKEND x11 \
            --unset WAYLAND_DISPLAY \
            --add-flags "--ozone-platform=x11 --force-device-scale-factor=1"
        '';
      };
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
          assertion = !enabled || mo2LintPkg != null;
          message = "features.gaming.enable is true, but the 'mo2-lint' package could not be resolved. Ensure the mo2LintOverlay is applied.";
        }
        {
          assertion = !enabled || rustyPathOfBuildingPkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'rusty-path-of-building' could not be resolved.";
        }
        {
          assertion = !enabled || awakenedPoeTradePkg != null;
          message = "features.gaming.enable is true, but nixpkgs package 'awakened-poe-trade' could not be resolved.";
        }
        {
          assertion = !pcsx2Enable || pcsx2Pkg != null;
          message = "features.gaming.pcsx2.enable is true, but nixpkgs package 'pcsx2' could not be resolved.";
        }
        {
          assertion = !(enabled && godotEnable) || godotPkg != null;
          message = "features.gaming.godot.enable is true, but nixpkgs package 'godot' could not be resolved.";
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
        # Steam's FHS env does not see Home Manager's icon path; without the
        # theme here it falls back to the X11 core cursor.
        extraPackages = lib.optionals (cursorPackage != null) [ cursorPackage ];
        gamescopeSession.enable = gamescopeSessionEnable;
        remotePlay.openFirewall = remotePlayOpenFirewall;
        dedicatedServer.openFirewall = dedicatedServerOpenFirewall;
        localNetworkGameTransfers.openFirewall = localTransfersOpenFirewall;
      };

      programs.gamescope = {
        enable = true;
        capSysNice = true;
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
        mo2LintPkg
        rustyPathOfBuildingPkg
        awakenedPoeTradePkg
      ]
      ++ lib.optionals cheatengineEnable [ cheatenginePkg ]
      ++ lib.optionals pcsx2Enable [ pcsx2Pkg ]
      ++ lib.optionals (enabled && godotEnable) [ godotPkg ];
    })
    (lib.mkIf (enabled && gamemodeEnable) {
      # GameMode: gamemoderun on PATH plus the polkit/setcap plumbing so the
      # primary user can drive it (Steam launch options: `gamemoderun %command%`).
      programs.gamemode.enable = true;
      users.users.${primaryUser}.extraGroups = [ "gamemode" ];
    })
    (lib.mkIf (enabled && cheatengineEnable) {
      # Grant Cheat Engine cap_sys_ptrace so it can scan and debug other
      # processes without lowering kernel.yama.ptrace_scope system-wide.
      # The wrapper copies the real ELF into /run/wrappers/bin with the file
      # capability set; the package's bin/cheatengine launcher execs this copy
      # after setting up LD_LIBRARY_PATH and cwd, so the capped process inherits
      # the full runtime env. Requires `switch` to materialize the wrapper.
      # Restrict execution to a dedicated group so only the configured primary
      # user (and any future explicit members) can invoke the privileged binary.
      users.groups.${cheatengineGroup} = { };
      users.users.${primaryUser}.extraGroups = lib.mkAfter [ cheatengineGroup ];
      security.wrappers.cheatengine-bin = {
        source = "${cheatenginePkg}/opt/cheatengine/cheatengine-x86_64";
        capabilities = "cap_sys_ptrace+ep";
        owner = "root";
        group = cheatengineGroup;
        permissions = "0750";
      };
    })
  ];
}
