{ lib, vars }:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "hyprland";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  compositors = [ compositor ] ++ extraCompositors;
  hasNiri = builtins.elem "niri" compositors;
  hasHyprland = builtins.elem "hyprland" compositors;
  hasPlasma = builtins.elem "plasma" compositors;
  hasWaylandCompositor = hasNiri || hasHyprland;
  sessionShell = get [ "desktop" "sessionShell" ] (
    if hasWaylandCompositor then "noctalia" else "none"
  );
  noctaliaCommand = get [ "desktop" "noctalia" "command" ] "nagi-noctalia-shell";
  noctaliaEnable = get [ "desktop" "noctalia" "enable" ] (sessionShell == "noctalia");
  qtThemeEnabled =
    get [ "features" "stylix" "enable" ] true && get [ "features" "theme" "qt" "enable" ] true;
  nvidia = get [ "graphics" "profile" ] "auto" == "nvidia";
  primaryUser = get [ "users" "primary" ] "nagi";
  homeDirectory = "/home/${primaryUser}";
  fullShell = builtins.elem sessionShell [
    "noctalia"
    "dms"
    "caelestia"
    "inir"
    "ii"
  ];
  qt6ctEnv = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
  };
  toolkitEnv =
    if sessionShell == "dms" then
      {
        QT_QPA_PLATFORMTHEME = "gtk3";
        QT_QPA_PLATFORMTHEME_QT6 = "gtk3";
        QT_QPA_PLATFORM = "wayland";
      }
    else if
      builtins.elem sessionShell [
        "caelestia"
        "inir"
        "ii"
      ]
    then
      qt6ctEnv
    else if sessionShell == "noctalia" && qtThemeEnabled then
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
  startupCommand =
    if sessionShell == "noctalia" then
      noctaliaCommand
    else if sessionShell == "dms" then
      "dms run"
    else if sessionShell == "caelestia" then
      "caelestia shell -d"
    else if sessionShell == "inir" then
      "inir run"
    else if sessionShell == "ii" then
      "ii"
    else
      null;
  startupArgs =
    if sessionShell == "noctalia" then
      [ noctaliaCommand ]
    else if sessionShell == "dms" then
      [
        "dms"
        "run"
      ]
    else if sessionShell == "caelestia" then
      [
        "caelestia"
        "shell"
        "-d"
      ]
    else if sessionShell == "inir" then
      [
        "inir"
        "run"
      ]
    else if sessionShell == "ii" then
      [ "ii" ]
    else
      null;
  lockCommand =
    if sessionShell == "noctalia" then
      "${noctaliaCommand} msg session lock"
    else if sessionShell == "dms" then
      "dms ipc call lock lock"
    else if sessionShell == "caelestia" then
      "caelestia shell lock lock"
    else if sessionShell == "inir" then
      "inir lock activate"
    else if sessionShell == "ii" then
      "ii ipc call lock activate"
    else
      "loginctl lock-session";
in
{
  inherit
    desktopEnabled
    compositor
    extraCompositors
    compositors
    hasNiri
    hasHyprland
    hasPlasma
    hasWaylandCompositor
    sessionShell
    noctaliaCommand
    noctaliaEnable
    qtThemeEnabled
    nvidia
    primaryUser
    homeDirectory
    fullShell
    toolkitEnv
    sharedEnv
    startupCommand
    startupArgs
    lockCommand
    ;
  dmsEnable = sessionShell == "dms";
  caelestiaEnable = sessionShell == "caelestia";
  inirEnable = sessionShell == "inir";
  iiEnable = sessionShell == "ii";
  noneEnable = sessionShell == "none";
  shellOwnsIdle = desktopEnabled && fullShell && hasWaylandCompositor;
  plasmaOwnsIdle = hasPlasma && !hasNiri && !hasHyprland;
  matePolkitEnable = sessionShell == "none";
}
