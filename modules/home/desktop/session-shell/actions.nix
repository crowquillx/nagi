{
  lib,
  pkgs,
  vars,
  compositor,
}:
let
  shell = import ./lib.nix { inherit lib vars; };
  inherit (shell) sessionShell noctaliaCommand;

  noctalia = message: "${noctaliaCommand} msg ${message}";
  dms = target: fn: "dms ipc call ${target} ${fn}";
  caelestia = rest: "caelestia shell ${rest}";
  inir = target: fn: "inir ${target} ${fn}";
  ii = target: fn: "ii ipc call ${target} ${fn}";

  volumeUp = "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+";
  volumeDown = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
  volumeMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
  brightnessUp = "brightnessctl set 5%+";
  brightnessDown = "brightnessctl set 5%-";
  taskManagerHtop = "ghostty -e htop";

  workspaceRenameHyprland = pkgs.writeShellApplication {
    name = "nagi-hyprland-rename-workspace";
    runtimeInputs = [
      pkgs.fuzzel
      pkgs.hyprland
    ];
    text = ''
      name="$(printf '\n' | fuzzel --dmenu --prompt 'Workspace name: ')"
      [[ -n "$name" ]] || exit 0
      hyprctl dispatch renameworkspace "current $name"
    '';
  };

  workspaceRenameNiri = pkgs.writeShellApplication {
    name = "nagi-niri-rename-workspace";
    runtimeInputs = [
      pkgs.fuzzel
      pkgs.niri
    ];
    text = ''
      name="$(printf '\n' | fuzzel --dmenu --prompt 'Workspace name: ')"
      [[ -n "$name" ]] || exit 0
      niri msg action set-workspace-name "$name"
    '';
  };

  clipboardFuzzel = pkgs.writeShellApplication {
    name = "nagi-clipboard-fuzzel";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.fuzzel
      pkgs.wl-clipboard
    ];
    text = ''
      cliphist list | fuzzel --dmenu --prompt 'Clipboard: ' | cliphist decode | wl-copy
    '';
  };

  renameHelper =
    if compositor == "hyprland" then
      "${workspaceRenameHyprland}/bin/nagi-hyprland-rename-workspace"
    else
      "${workspaceRenameNiri}/bin/nagi-niri-rename-workspace";

  noneClipboard = "${clipboardFuzzel}/bin/nagi-clipboard-fuzzel";

  windowSwitcher =
    if compositor == "niri" then
      {
        mode = "overview";
        command = null;
      }
    else if sessionShell == "noctalia" then
      {
        mode = "command";
        command = noctalia "window-switcher";
      }
    else if sessionShell == "dms" then
      {
        mode = "command";
        command = dms "hypr" "toggleOverview";
      }
    else if sessionShell == "inir" then
      {
        mode = "command";
        command = inir "altSwitcher" "toggle";
      }
    else if sessionShell == "ii" then
      {
        mode = "command";
        command = ii "search" "toggle";
      }
    else
      {
        mode = "omit";
        command = null;
      };
in
{
  inherit windowSwitcher;

  launcher =
    if sessionShell == "noctalia" then
      noctalia "panel-toggle launcher"
    else if sessionShell == "dms" then
      dms "spotlight" "toggle"
    else if sessionShell == "caelestia" then
      caelestia "drawers toggle launcher"
    else if sessionShell == "inir" then
      inir "overview" "toggle"
    else if sessionShell == "ii" then
      ii "search" "toggle"
    else
      "fuzzel";

  clipboard =
    if sessionShell == "noctalia" then
      noctalia "panel-toggle clipboard"
    else if sessionShell == "dms" then
      dms "clipboard" "toggle"
    else if sessionShell == "caelestia" then
      null
    else if sessionShell == "inir" then
      inir "clipboard" "toggle"
    else if sessionShell == "ii" then
      ii "search" "clipboardToggle"
    else
      noneClipboard;

  controlCenter =
    if sessionShell == "noctalia" then
      noctalia "panel-toggle control-center"
    else if sessionShell == "dms" then
      dms "control-center" "toggle"
    else if sessionShell == "caelestia" then
      caelestia "drawers toggle sidebar"
    else if sessionShell == "inir" then
      inir "controlPanel" "toggle"
    else if sessionShell == "ii" then
      ii "sidebarRight" "toggle"
    else
      null;

  lock =
    if sessionShell == "noctalia" then
      noctalia "session lock"
    else if sessionShell == "dms" then
      dms "lock" "lock"
    else if sessionShell == "caelestia" then
      caelestia "lock lock"
    else if sessionShell == "inir" then
      inir "lock" "activate"
    else if sessionShell == "ii" then
      ii "lock" "activate"
    else
      "loginctl lock-session";

  volumeUp =
    if sessionShell == "noctalia" then
      noctalia "volume-up"
    else if sessionShell == "dms" then
      dms "audio" "increment"
    else if sessionShell == "inir" then
      inir "audio" "volumeUp"
    else
      volumeUp;

  volumeDown =
    if sessionShell == "noctalia" then
      noctalia "volume-down"
    else if sessionShell == "dms" then
      dms "audio" "decrement"
    else if sessionShell == "inir" then
      inir "audio" "volumeDown"
    else
      volumeDown;

  volumeMute =
    if sessionShell == "noctalia" then
      noctalia "volume-mute"
    else if sessionShell == "dms" then
      dms "audio" "mute"
    else if sessionShell == "inir" then
      inir "audio" "mute"
    else
      volumeMute;

  brightnessUp =
    if sessionShell == "noctalia" then
      noctalia "brightness-up"
    else if sessionShell == "dms" then
      "${dms "brightness" "increment"} 5 \"\""
    else if sessionShell == "inir" then
      inir "brightness" "increment"
    else if sessionShell == "ii" then
      ii "brightness" "increment"
    else
      brightnessUp;

  brightnessDown =
    if sessionShell == "noctalia" then
      noctalia "brightness-down"
    else if sessionShell == "dms" then
      "${dms "brightness" "decrement"} 5 \"\""
    else if sessionShell == "inir" then
      inir "brightness" "decrement"
    else if sessionShell == "ii" then
      ii "brightness" "decrement"
    else
      brightnessDown;

  taskManager =
    if sessionShell == "dms" then
      dms "processlist" "focusOrToggle"
    else if sessionShell == "caelestia" then
      null
    else
      taskManagerHtop;

  workspaceRename =
    if sessionShell == "dms" then
      dms "workspace-rename" "open"
    else if sessionShell == "caelestia" then
      null
    else
      renameHelper;

  notifications =
    if sessionShell == "noctalia" then
      noctalia "panel-toggle control-center notifications"
    else if sessionShell == "dms" then
      dms "notifications" "toggle"
    else
      null;

  settings =
    if sessionShell == "noctalia" then
      noctalia "settings-toggle"
    else if sessionShell == "dms" then
      dms "settings" "focusOrToggle"
    else if sessionShell == "caelestia" then
      caelestia "nexus open"
    else if sessionShell == "inir" then
      "inir settings"
    else if sessionShell == "ii" then
      "ii-settings"
    else
      null;

  wallpaper =
    if sessionShell == "noctalia" then
      noctalia "panel-toggle wallpaper"
    else if sessionShell == "dms" then
      dms "dankdash" "wallpaper"
    else if sessionShell == "inir" then
      inir "wallpaperSelector" "toggle"
    else
      null;
}
