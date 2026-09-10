{ lib, vars }:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "umbriel";
  hasUmbriel = compositor == "umbriel";
  hasWaylandCompositor = hasUmbriel;
  sessionShell = get [ "desktop" "sessionShell" ] "noctalia";
  noctaliaCommand = get [ "desktop" "noctalia" "command" ] "nagi-noctalia-shell";
  noctaliaEnable = get [ "desktop" "noctalia" "enable" ] (sessionShell == "noctalia");
  sessionCommands = import ../../../../lib/session-shell-commands.nix {
    inherit sessionShell noctaliaCommand;
  };
  inherit (sessionCommands)
    startupCommand
    startupArgs
    lockCommand
    restart
    ;
  qtThemeEnabled = get [ "features" "theme" "qt" "enable" ] true;
  nvidia = get [ "graphics" "profile" ] "auto" == "nvidia";
  primaryUser = get [ "users" "primary" ] "nagi";
  homeDirectory = "/home/${primaryUser}";
  toolkitEnv =
    if sessionShell == "noctalia" && qtThemeEnabled then
      {
        QT_QPA_PLATFORMTHEME = "qt5ct";
        QT_STYLE_OVERRIDE = "kvantum";
      }
    else
      { };
  sharedEnv = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  }
  // lib.optionalAttrs nvidia { NVD_BACKEND = "direct"; };
in
{
  inherit
    desktopEnabled
    compositor
    hasUmbriel
    hasWaylandCompositor
    sessionShell
    noctaliaCommand
    noctaliaEnable
    qtThemeEnabled
    nvidia
    primaryUser
    homeDirectory
    toolkitEnv
    sharedEnv
    startupCommand
    startupArgs
    lockCommand
    restart
    ;
  shellOwnsIdle = desktopEnabled && sessionShell == "noctalia" && hasUmbriel;
  matePolkitEnable = false;
}
