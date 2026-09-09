{
  lib,
  pkgs,
  vars,
  node,
  leaf,
  flag,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  actions = import ../session-shell/actions.nix {
    inherit lib pkgs vars;
    compositor = "niri";
  };
  cmdBind =
    key: title: command:
    if command == null then
      null
    else
      node key { "hotkey-overlay-title" = title; } [
        (leaf "spawn-sh" command)
      ];
  flagBind = key: action: node key [ ] [ (flag action) ];
  leafBind =
    key: action: value:
    node key [ ] [ (leaf action value) ];
  nonRepeatingFlagBind = key: action: node key { repeat = false; } [ (flag action) ];
  cooldownFlagBind = key: action: node key { "cooldown-ms" = 150; } [ (flag action) ];
  workspaceBinds =
    modifier: action:
    map (workspace: leafBind "${modifier}${toString workspace}" action workspace) (lib.range 1 9);
  chatClient = get [ "features" "chat" "client" ] "none";
  packageNames = get [ "users" "extraPackages" ] [ ];
  handyEnabled = builtins.elem "handy" packageNames;
  handyToggleCommand = if handyEnabled then "nagi-handy-toggle-transcription" else null;
  handyToggleBind =
    if handyToggleCommand == null then
      null
    else
      node "Mod+O"
        {
          "hotkey-overlay-title" = "Toggle Handy transcription";
          "allow-inhibiting" = false;
        }
        [
          (leaf "spawn-sh" handyToggleCommand)
        ];
  effectiveChatClient =
    if chatClient != "none" then
      chatClient
    else if builtins.elem "equibop" packageNames then
      "equibop"
    else if builtins.elem "discord" packageNames then
      "discord"
    else
      "none";
  microphoneMuteScript = pkgs.writeShellApplication {
    name = "nagi-toggle-microphone-mute";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.wireplumber
    ];
    text = ''
      set -euo pipefail

      source="@DEFAULT_AUDIO_SOURCE@"

      wpctl set-mute "$source" toggle

      if wpctl get-volume "$source" | grep -q '\[MUTED\]'; then
        notify-send "Microphone" "Muted"
      else
        notify-send "Microphone" "Unmuted"
      fi
    '';
  };
  chatMuteAction =
    if effectiveChatClient == "equibop" then
      [
        (leaf "spawn" [
          "${pkgs.equibop}/bin/equibop"
          "--toggle-mic"
        ])
      ]
    else if effectiveChatClient != "none" then
      [ (leaf "spawn" [ "${microphoneMuteScript}/bin/nagi-toggle-microphone-mute" ]) ]
    else
      [
        (leaf "spawn" [
          "notify-send"
          "Chat mute"
          "No chat client is configured."
        ])
      ];
in
[
  (node "binds" [ ] (
    lib.flatten (
      lib.remove null [
        (cmdBind "Mod+D" "Launcher" actions.launcher)
        (nonRepeatingFlagBind "Mod+Space" "toggle-overview")
        (nonRepeatingFlagBind "Mod+Tab" "toggle-overview")
        (node "Mod+Shift+Slash"
          [ ]
          [
            (flag "show-hotkey-overlay")
          ]
        )

        (node "Mod+T" { "hotkey-overlay-title" = "Open Kitty"; } [
          (leaf "spawn" [ "kitty" ])
        ])
        (node "Mod+Return" { "hotkey-overlay-title" = "Open Ghostty"; } [
          (leaf "spawn" [ "ghostty" ])
        ])
        (cmdBind "Mod+V" "Clipboard Manager" actions.clipboard)
        (cmdBind "Mod+M" "Task Manager" actions.taskManager)
        # Package wrapper already forces Electron onto X11/XWayland; just spawn it.
        (node "Mod+Alt+P" { "hotkey-overlay-title" = "Awakened PoE Trade"; } [
          (leaf "spawn" [ "awakened-poe-trade" ])
        ])
        (node "Super+E" { "hotkey-overlay-title" = "File Manager"; } [
          (leaf "spawn" [ "thunar" ])
        ])
        (node "Mod+Z" { "hotkey-overlay-title" = "Zen Browser (Beta)"; } [
          (leaf "spawn" [ "zen-beta" ])
        ])
        (node "Mod+Shift+Z" { "hotkey-overlay-title" = "Mullvad Browser"; } [
          (leaf "spawn" [ "mullvad-browser" ])
        ])
        handyToggleBind
        (node "MouseForward" { "hotkey-overlay-title" = "Chat: Toggle Mute"; } chatMuteAction)
        (cmdBind "Super+B" "Control Center" actions.controlCenter)
        (cmdBind "Mod+N" "Notification Center" actions.notifications)
        (cmdBind "Mod+Comma" "Settings" actions.settings)
        (cmdBind "Mod+Y" "Wallpaper" actions.wallpaper)

        (cmdBind "XF86AudioRaiseVolume" "Volume Up" actions.volumeUp)
        (cmdBind "XF86AudioLowerVolume" "Volume Down" actions.volumeDown)
        (cmdBind "XF86AudioMute" "Volume Mute" actions.volumeMute)
        (cmdBind "XF86MonBrightnessUp" "Brightness Up" actions.brightnessUp)
        (cmdBind "XF86MonBrightnessDown" "Brightness Down" actions.brightnessDown)

        (nonRepeatingFlagBind "Mod+Q" "close-window")
        (flagBind "Mod+F" "maximize-column")
        (flagBind "Mod+Shift+F" "fullscreen-window")
        (flagBind "Mod+Shift+T" "toggle-window-floating")
        (flagBind "Mod+Shift+V" "switch-focus-between-floating-and-tiling")
        (flagBind "Mod+W" "toggle-column-tabbed-display")

        (flagBind "Mod+Left" "focus-column-left")
        (flagBind "Mod+Down" "focus-window-down")
        (flagBind "Mod+Up" "focus-window-up")
        (flagBind "Mod+Right" "focus-column-right")
        (flagBind "Mod+H" "focus-column-left")
        (flagBind "Mod+J" "focus-window-down")
        (flagBind "Mod+K" "focus-window-up")
        (cmdBind "Mod+L" "Lock Session" actions.lock)

        (flagBind "Mod+Shift+Left" "move-column-left")
        (flagBind "Mod+Shift+Down" "move-window-down")
        (flagBind "Mod+Shift+Up" "move-window-up")
        (flagBind "Mod+Shift+Right" "move-column-right")
        (flagBind "Mod+Shift+H" "move-column-left")
        (flagBind "Mod+Shift+J" "move-window-down")
        (flagBind "Mod+Shift+K" "move-window-up")
        (flagBind "Mod+Shift+L" "move-column-right")

        (flagBind "Mod+Home" "focus-column-first")
        (flagBind "Mod+End" "focus-column-last")
        (flagBind "Mod+Ctrl+Home" "move-column-to-first")
        (flagBind "Mod+Ctrl+End" "move-column-to-last")

        (flagBind "Mod+Ctrl+Left" "focus-monitor-left")
        (flagBind "Mod+Ctrl+Right" "focus-monitor-right")
        (flagBind "Mod+Ctrl+H" "focus-monitor-left")
        (flagBind "Mod+Ctrl+J" "focus-monitor-down")
        (flagBind "Mod+Ctrl+K" "focus-monitor-up")
        (flagBind "Mod+Ctrl+L" "focus-monitor-right")

        (flagBind "Mod+Shift+Ctrl+Left" "move-column-to-monitor-left")
        (flagBind "Mod+Shift+Ctrl+Down" "move-column-to-monitor-down")
        (flagBind "Mod+Shift+Ctrl+Up" "move-column-to-monitor-up")
        (flagBind "Mod+Shift+Ctrl+Right" "move-column-to-monitor-right")
        (flagBind "Mod+Shift+Ctrl+H" "move-column-to-monitor-left")
        (flagBind "Mod+Shift+Ctrl+J" "move-column-to-monitor-down")
        (flagBind "Mod+Shift+Ctrl+K" "move-column-to-monitor-up")
        (flagBind "Mod+Shift+Ctrl+L" "move-column-to-monitor-right")

        (flagBind "Mod+Page_Down" "focus-workspace-down")
        (flagBind "Mod+Page_Up" "focus-workspace-up")
        (flagBind "Mod+U" "focus-workspace-down")
        (flagBind "Mod+I" "focus-workspace-up")
        (flagBind "Mod+Ctrl+Down" "focus-workspace-down")
        (flagBind "Mod+Ctrl+Up" "focus-workspace-up")
        (flagBind "Mod+Ctrl+U" "focus-workspace-down")
        (flagBind "Mod+Ctrl+I" "focus-workspace-up")

        (cmdBind "Ctrl+Shift+R" "Rename Workspace" actions.workspaceRename)

        (flagBind "Mod+Shift+Page_Down" "move-workspace-down")
        (flagBind "Mod+Shift+Page_Up" "move-workspace-up")
        (flagBind "Mod+Shift+U" "move-workspace-down")
        (flagBind "Mod+Shift+I" "move-workspace-up")

        (cooldownFlagBind "Mod+WheelScrollDown" "focus-workspace-down")
        (cooldownFlagBind "Mod+WheelScrollUp" "focus-workspace-up")
        (cooldownFlagBind "Mod+Ctrl+WheelScrollDown" "move-column-to-workspace-down")
        (cooldownFlagBind "Mod+Ctrl+WheelScrollUp" "move-column-to-workspace-up")
        (flagBind "Mod+WheelScrollRight" "focus-column-right")
        (flagBind "Mod+WheelScrollLeft" "focus-column-left")
        (flagBind "Mod+Ctrl+WheelScrollRight" "move-column-right")
        (flagBind "Mod+Ctrl+WheelScrollLeft" "move-column-left")
        (flagBind "Mod+Shift+WheelScrollDown" "focus-column-right")
        (flagBind "Mod+Shift+WheelScrollUp" "focus-column-left")
        (flagBind "Mod+Ctrl+Shift+WheelScrollDown" "move-column-right")
        (flagBind "Mod+Ctrl+Shift+WheelScrollUp" "move-column-left")

        (workspaceBinds "Mod+" "focus-workspace")

        (workspaceBinds "Mod+Shift+" "move-column-to-workspace")

        (flagBind "Mod+BracketLeft" "consume-or-expel-window-left")
        (flagBind "Mod+BracketRight" "consume-or-expel-window-right")
        (flagBind "Mod+Period" "expel-window-from-column")

        (flagBind "Mod+R" "switch-preset-column-width")
        (flagBind "Mod+Shift+R" "switch-preset-window-height")
        (flagBind "Mod+Ctrl+R" "reset-window-height")
        (flagBind "Mod+Ctrl+F" "expand-column-to-available-width")
        (flagBind "Mod+C" "center-column")
        (flagBind "Mod+Ctrl+C" "center-visible-columns")

        (leafBind "Mod+Minus" "set-column-width" "-10%")
        (leafBind "Mod+Equal" "set-column-width" "+10%")
        (leafBind "Mod+Shift+Minus" "set-window-height" "-10%")
        (leafBind "Mod+Shift+Equal" "set-window-height" "+10%")

        (flagBind "XF86Launch1" "screenshot")
        (flagBind "Ctrl+XF86Launch1" "screenshot-screen")
        (flagBind "Alt+XF86Launch1" "screenshot-window")
        (flagBind "Print" "screenshot")
        (flagBind "Ctrl+Print" "screenshot-screen")
        (flagBind "Alt+Print" "screenshot-window")
        (node "Mod+Escape" { "allow-inhibiting" = false; } [
          (flag "toggle-keyboard-shortcuts-inhibit")
        ])
        (flagBind "Mod+Shift+P" "power-off-monitors")
      ]
    )
  ))
]
