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
  noctaliaCommand = get [ "desktop" "noctalia" "command" ] "noctalia";
  chatClient = get [ "features" "chat" "client" ] "none";
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
    if chatClient == "equibop" then
      [ (leaf "spawn" [ "equibop" "--toggle-mic" ]) ]
    else if chatClient != "none" then
      [ (leaf "spawn" [ "${microphoneMuteScript}/bin/nagi-toggle-microphone-mute" ]) ]
    else
      [ (leaf "spawn" [ "notify-send" "Chat mute" "No chat client is configured." ]) ];
in
[
  (node "binds" [ ] [
    (node "Mod+D" [ ] [
      (leaf "spawn-sh" "${noctaliaCommand} msg panel-toggle launcher")
    ])
    (node "Mod+Space" { repeat = false; } [
      (flag "toggle-overview")
    ])
    (node "Mod+Tab" { repeat = false; } [
      (flag "toggle-overview")
    ])
    (node "Mod+Shift+Slash" [ ] [
      (flag "show-hotkey-overlay")
    ])

    (node "Mod+T" { "hotkey-overlay-title" = "Open Terminal"; } [
      (leaf "spawn" [ "ghostty" ])
    ])
    (node "Mod+Return" { "hotkey-overlay-title" = "Open Terminal"; } [
      (leaf "spawn" [ "kitty" ])
    ])
    (node "Mod+V" { "hotkey-overlay-title" = "Clipboard Manager"; } [
      (leaf "spawn" [ "dms" "ipc" "call" "clipboard" "toggle" ])
    ])
    (node "Mod+M" { "hotkey-overlay-title" = "Task Manager"; } [
      (leaf "spawn" [ "dms" "ipc" "call" "processlist" "focusOrToggle" ])
    ])
    (node "Mod+Alt+P" { "hotkey-overlay-title" = "Awakened PoE Trade"; } [
      (leaf "spawn" [ "sh" "-c" "XDG_SESSION_TYPE=x11 GDK_BACKEND=x11 exec env -u WAYLAND_DISPLAY awakened-poe-trade" ])
    ])
    (node "Super+E" { "hotkey-overlay-title" = "File Manager"; } [
      (leaf "spawn" [ "thunar" ])
    ])
    (node "Mod+Z" { "hotkey-overlay-title" = "Zen Browser"; } [
      (leaf "spawn" [ "zen" ])
    ])
    (node "Mod+Shift+Z" { "hotkey-overlay-title" = "Mullvad Browser"; } [
      (leaf "spawn" [ "mullvad-browser" ])
    ])
    (node "MouseForward" { "hotkey-overlay-title" = "Chat: Toggle Mute"; } chatMuteAction)
    (node "Super+B" { "hotkey-overlay-title" = "Assistant Panel: Toggle"; } [
      (leaf "spawn-sh" "${noctaliaCommand} msg panel-toggle control-center")
    ])

    (node "XF86AudioRaiseVolume" [ ] [
      (leaf "spawn-sh" "${noctaliaCommand} msg volume-up")
    ])
    (node "XF86AudioLowerVolume" [ ] [
      (leaf "spawn-sh" "${noctaliaCommand} msg volume-down")
    ])
    (node "XF86AudioMute" [ ] [
      (leaf "spawn-sh" "${noctaliaCommand} msg volume-mute")
    ])
    (node "XF86MonBrightnessUp" [ ] [
      (leaf "spawn-sh" "${noctaliaCommand} msg brightness-up")
    ])
    (node "XF86MonBrightnessDown" [ ] [
      (leaf "spawn-sh" "${noctaliaCommand} msg brightness-down")
    ])

    (node "Mod+Q" { repeat = false; } [
      (flag "close-window")
    ])
    (node "Mod+F" [ ] [
      (flag "maximize-column")
    ])
    (node "Mod+Shift+F" [ ] [
      (flag "fullscreen-window")
    ])
    (node "Mod+Shift+T" [ ] [
      (flag "toggle-window-floating")
    ])
    (node "Mod+Shift+V" [ ] [
      (flag "switch-focus-between-floating-and-tiling")
    ])
    (node "Mod+W" [ ] [
      (flag "toggle-column-tabbed-display")
    ])

    (node "Mod+Left" [ ] [
      (flag "focus-column-left")
    ])
    (node "Mod+Down" [ ] [
      (flag "focus-window-down")
    ])
    (node "Mod+Up" [ ] [
      (flag "focus-window-up")
    ])
    (node "Mod+Right" [ ] [
      (flag "focus-column-right")
    ])
    (node "Mod+H" [ ] [
      (flag "focus-column-left")
    ])
    (node "Mod+J" [ ] [
      (flag "focus-window-down")
    ])
    (node "Mod+K" [ ] [
      (flag "focus-window-up")
    ])
    (node "Mod+L" [ ] [
      (leaf "spawn-sh" "${noctaliaCommand} msg session lock")
    ])

    (node "Mod+Shift+Left" [ ] [
      (flag "move-column-left")
    ])
    (node "Mod+Shift+Down" [ ] [
      (flag "move-window-down")
    ])
    (node "Mod+Shift+Up" [ ] [
      (flag "move-window-up")
    ])
    (node "Mod+Shift+Right" [ ] [
      (flag "move-column-right")
    ])
    (node "Mod+Shift+H" [ ] [
      (flag "move-column-left")
    ])
    (node "Mod+Shift+J" [ ] [
      (flag "move-window-down")
    ])
    (node "Mod+Shift+K" [ ] [
      (flag "move-window-up")
    ])
    (node "Mod+Shift+L" [ ] [
      (flag "move-column-right")
    ])

    (node "Mod+Home" [ ] [
      (flag "focus-column-first")
    ])
    (node "Mod+End" [ ] [
      (flag "focus-column-last")
    ])
    (node "Mod+Ctrl+Home" [ ] [
      (flag "move-column-to-first")
    ])
    (node "Mod+Ctrl+End" [ ] [
      (flag "move-column-to-last")
    ])

    (node "Mod+Ctrl+Left" [ ] [
      (flag "focus-monitor-left")
    ])
    (node "Mod+Ctrl+Right" [ ] [
      (flag "focus-monitor-right")
    ])
    (node "Mod+Ctrl+H" [ ] [
      (flag "focus-monitor-left")
    ])
    (node "Mod+Ctrl+J" [ ] [
      (flag "focus-monitor-down")
    ])
    (node "Mod+Ctrl+K" [ ] [
      (flag "focus-monitor-up")
    ])
    (node "Mod+Ctrl+L" [ ] [
      (flag "focus-monitor-right")
    ])

    (node "Mod+Shift+Ctrl+Left" [ ] [
      (flag "move-column-to-monitor-left")
    ])
    (node "Mod+Shift+Ctrl+Down" [ ] [
      (flag "move-column-to-monitor-down")
    ])
    (node "Mod+Shift+Ctrl+Up" [ ] [
      (flag "move-column-to-monitor-up")
    ])
    (node "Mod+Shift+Ctrl+Right" [ ] [
      (flag "move-column-to-monitor-right")
    ])
    (node "Mod+Shift+Ctrl+H" [ ] [
      (flag "move-column-to-monitor-left")
    ])
    (node "Mod+Shift+Ctrl+J" [ ] [
      (flag "move-column-to-monitor-down")
    ])
    (node "Mod+Shift+Ctrl+K" [ ] [
      (flag "move-column-to-monitor-up")
    ])
    (node "Mod+Shift+Ctrl+L" [ ] [
      (flag "move-column-to-monitor-right")
    ])

    (node "Mod+Page_Down" [ ] [
      (flag "focus-workspace-down")
    ])
    (node "Mod+Page_Up" [ ] [
      (flag "focus-workspace-up")
    ])
    (node "Mod+U" [ ] [
      (flag "focus-workspace-down")
    ])
    (node "Mod+I" [ ] [
      (flag "focus-workspace-up")
    ])
    (node "Mod+Ctrl+Down" [ ] [
      (flag "focus-workspace-down")
    ])
    (node "Mod+Ctrl+Up" [ ] [
      (flag "focus-workspace-up")
    ])
    (node "Mod+Ctrl+U" [ ] [
      (flag "focus-workspace-down")
    ])
    (node "Mod+Ctrl+I" [ ] [
      (flag "focus-workspace-up")
    ])

    (node "Ctrl+Shift+R" { "hotkey-overlay-title" = "Rename Workspace"; } [
      (leaf "spawn" [ "dms" "ipc" "call" "workspace-rename" "open" ])
    ])

    (node "Mod+Shift+Page_Down" [ ] [
      (flag "move-workspace-down")
    ])
    (node "Mod+Shift+Page_Up" [ ] [
      (flag "move-workspace-up")
    ])
    (node "Mod+Shift+U" [ ] [
      (flag "move-workspace-down")
    ])
    (node "Mod+Shift+I" [ ] [
      (flag "move-workspace-up")
    ])

    (node "Mod+WheelScrollDown" { "cooldown-ms" = 150; } [
      (flag "focus-workspace-down")
    ])
    (node "Mod+WheelScrollUp" { "cooldown-ms" = 150; } [
      (flag "focus-workspace-up")
    ])
    (node "Mod+Ctrl+WheelScrollDown" { "cooldown-ms" = 150; } [
      (flag "move-column-to-workspace-down")
    ])
    (node "Mod+Ctrl+WheelScrollUp" { "cooldown-ms" = 150; } [
      (flag "move-column-to-workspace-up")
    ])
    (node "Mod+WheelScrollRight" [ ] [
      (flag "focus-column-right")
    ])
    (node "Mod+WheelScrollLeft" [ ] [
      (flag "focus-column-left")
    ])
    (node "Mod+Ctrl+WheelScrollRight" [ ] [
      (flag "move-column-right")
    ])
    (node "Mod+Ctrl+WheelScrollLeft" [ ] [
      (flag "move-column-left")
    ])
    (node "Mod+Shift+WheelScrollDown" [ ] [
      (flag "focus-column-right")
    ])
    (node "Mod+Shift+WheelScrollUp" [ ] [
      (flag "focus-column-left")
    ])
    (node "Mod+Ctrl+Shift+WheelScrollDown" [ ] [
      (flag "move-column-right")
    ])
    (node "Mod+Ctrl+Shift+WheelScrollUp" [ ] [
      (flag "move-column-left")
    ])

    (node "Mod+1" [ ] [
      (leaf "focus-workspace" 1)
    ])
    (node "Mod+2" [ ] [
      (leaf "focus-workspace" 2)
    ])
    (node "Mod+3" [ ] [
      (leaf "focus-workspace" 3)
    ])
    (node "Mod+4" [ ] [
      (leaf "focus-workspace" 4)
    ])
    (node "Mod+5" [ ] [
      (leaf "focus-workspace" 5)
    ])
    (node "Mod+6" [ ] [
      (leaf "focus-workspace" 6)
    ])
    (node "Mod+7" [ ] [
      (leaf "focus-workspace" 7)
    ])
    (node "Mod+8" [ ] [
      (leaf "focus-workspace" 8)
    ])
    (node "Mod+9" [ ] [
      (leaf "focus-workspace" 9)
    ])

    (node "Mod+Shift+1" [ ] [
      (leaf "move-column-to-workspace" 1)
    ])
    (node "Mod+Shift+2" [ ] [
      (leaf "move-column-to-workspace" 2)
    ])
    (node "Mod+Shift+3" [ ] [
      (leaf "move-column-to-workspace" 3)
    ])
    (node "Mod+Shift+4" [ ] [
      (leaf "move-column-to-workspace" 4)
    ])
    (node "Mod+Shift+5" [ ] [
      (leaf "move-column-to-workspace" 5)
    ])
    (node "Mod+Shift+6" [ ] [
      (leaf "move-column-to-workspace" 6)
    ])
    (node "Mod+Shift+7" [ ] [
      (leaf "move-column-to-workspace" 7)
    ])
    (node "Mod+Shift+8" [ ] [
      (leaf "move-column-to-workspace" 8)
    ])
    (node "Mod+Shift+9" [ ] [
      (leaf "move-column-to-workspace" 9)
    ])

    (node "Mod+BracketLeft" [ ] [
      (flag "consume-or-expel-window-left")
    ])
    (node "Mod+BracketRight" [ ] [
      (flag "consume-or-expel-window-right")
    ])
    (node "Mod+Period" [ ] [
      (flag "expel-window-from-column")
    ])

    (node "Mod+R" [ ] [
      (flag "switch-preset-column-width")
    ])
    (node "Mod+Shift+R" [ ] [
      (flag "switch-preset-window-height")
    ])
    (node "Mod+Ctrl+R" [ ] [
      (flag "reset-window-height")
    ])
    (node "Mod+Ctrl+F" [ ] [
      (flag "expand-column-to-available-width")
    ])
    (node "Mod+C" [ ] [
      (flag "center-column")
    ])
    (node "Mod+Ctrl+C" [ ] [
      (flag "center-visible-columns")
    ])

    (node "Mod+Minus" [ ] [
      (leaf "set-column-width" "-10%")
    ])
    (node "Mod+Equal" [ ] [
      (leaf "set-column-width" "+10%")
    ])
    (node "Mod+Shift+Minus" [ ] [
      (leaf "set-window-height" "-10%")
    ])
    (node "Mod+Shift+Equal" [ ] [
      (leaf "set-window-height" "+10%")
    ])

    (node "XF86Launch1" [ ] [
      (flag "screenshot")
    ])
    (node "Ctrl+XF86Launch1" [ ] [
      (flag "screenshot-screen")
    ])
    (node "Alt+XF86Launch1" [ ] [
      (flag "screenshot-window")
    ])
    (node "Print" [ ] [
      (flag "screenshot")
    ])
    (node "Ctrl+Print" [ ] [
      (flag "screenshot-screen")
    ])
    (node "Alt+Print" [ ] [
      (flag "screenshot-window")
    ])
    (node "Mod+Escape" { "allow-inhibiting" = false; } [
      (flag "toggle-keyboard-shortcuts-inhibit")
    ])
    (node "Mod+Shift+P" [ ] [
      (flag "power-off-monitors")
    ])
  ])
]
