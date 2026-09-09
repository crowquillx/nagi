{
  lib,
  pkgs,
  vars,
  compositor,
}:
let
  shell = import ./lib.nix { inherit lib vars; };
  inherit (shell) sessionShell noctaliaCommand lockCommand;

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

  baseActions = {
    launcher = "fuzzel";
    clipboard = noneClipboard;
    controlCenter = null;
    lock = lockCommand;
    inherit
      volumeUp
      volumeDown
      volumeMute
      brightnessUp
      brightnessDown
      ;
    taskManager = taskManagerHtop;
    workspaceRename = renameHelper;
    notifications = null;
    settings = null;
    wallpaper = null;
    windowSwitcher = {
      mode = "omit";
      command = null;
    };
  };

  shellActions = {
    none = baseActions;
    noctalia = baseActions // {
      launcher = noctalia "panel-toggle launcher";
      clipboard = noctalia "panel-toggle clipboard";
      controlCenter = noctalia "panel-toggle control-center";
      volumeUp = noctalia "volume-up";
      volumeDown = noctalia "volume-down";
      volumeMute = noctalia "volume-mute";
      brightnessUp = noctalia "brightness-up";
      brightnessDown = noctalia "brightness-down";
      notifications = noctalia "panel-toggle control-center notifications";
      settings = noctalia "settings-toggle";
      wallpaper = noctalia "panel-toggle wallpaper";
      windowSwitcher = {
        mode = "command";
        command = noctalia "window-switcher";
      };
    };
    dms = baseActions // {
      launcher = dms "spotlight" "toggle";
      clipboard = dms "clipboard" "toggle";
      controlCenter = dms "control-center" "toggle";
      volumeUp = dms "audio" "increment";
      volumeDown = dms "audio" "decrement";
      volumeMute = dms "audio" "mute";
      brightnessUp = "${dms "brightness" "increment"} 5 \"\"";
      brightnessDown = "${dms "brightness" "decrement"} 5 \"\"";
      taskManager = dms "processlist" "focusOrToggle";
      workspaceRename = dms "workspace-rename" "open";
      notifications = dms "notifications" "toggle";
      settings = dms "settings" "focusOrToggle";
      wallpaper = dms "dankdash" "wallpaper";
      windowSwitcher = {
        mode = "command";
        command = dms "hypr" "toggleOverview";
      };
    };
    caelestia = baseActions // {
      launcher = caelestia "drawers toggle launcher";
      clipboard = null;
      controlCenter = caelestia "drawers toggle sidebar";
      taskManager = null;
      workspaceRename = null;
      settings = caelestia "nexus open";
    };
    inir = baseActions // {
      launcher = inir "overview" "toggle";
      clipboard = inir "clipboard" "toggle";
      controlCenter = inir "controlPanel" "toggle";
      volumeUp = inir "audio" "volumeUp";
      volumeDown = inir "audio" "volumeDown";
      volumeMute = inir "audio" "mute";
      brightnessUp = inir "brightness" "increment";
      brightnessDown = inir "brightness" "decrement";
      settings = "inir settings";
      wallpaper = inir "wallpaperSelector" "toggle";
      windowSwitcher = {
        mode = "command";
        command = inir "altSwitcher" "toggle";
      };
    };
    ii = baseActions // {
      launcher = ii "search" "toggle";
      clipboard = ii "search" "clipboardToggle";
      controlCenter = ii "sidebarRight" "toggle";
      brightnessUp = ii "brightness" "increment";
      brightnessDown = ii "brightness" "decrement";
      settings = "ii-settings";
      windowSwitcher = {
        mode = "command";
        command = ii "search" "toggle";
      };
    };
  };

  selected =
    if builtins.isString sessionShell && builtins.hasAttr sessionShell shellActions then
      shellActions.${sessionShell}
    else
      baseActions;

  windowSwitcher =
    if compositor == "niri" then
      {
        mode = "overview";
        command = null;
      }
    else
      selected.windowSwitcher;
in
selected // { inherit windowSwitcher; }
