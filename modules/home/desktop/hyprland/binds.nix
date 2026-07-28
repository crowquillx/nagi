{
  lib,
  pkgs,
  vars,
  quote,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  noctaliaCommand = get [ "desktop" "noctalia" "command" ] "nagi-noctalia-shell";
  chatClient = get [ "features" "chat" "client" ] "none";
  packageNames = get [ "users" "extraPackages" ] [ ];
  effectiveChatClient =
    if chatClient != "none" then
      chatClient
    else if builtins.elem "equibop" packageNames then
      "equibop"
    else if builtins.elem "discord" packageNames then
      "discord"
    else
      "none";
  chatMuteAction =
    if effectiveChatClient == "discord" then
      ''hl.dsp.send_shortcut({ mods = "CTRL SHIFT", key = "M", window = "class:(?i)^(discord|com\\.discordapp\\.Discord)$" })''
    else if effectiveChatClient == "equibop" then
      "hl.dsp.exec_cmd(${quote "equibop --toggle-mic"})"
    else
      "hl.dsp.exec_cmd(${quote "notify-send 'Chat mute' 'No chat client is configured.'"})";
  chatMuteDescription =
    if effectiveChatClient == "discord" then "Discord: toggle mute" else "Chat: toggle mute";
  workspaceRenameScript = pkgs.writeShellApplication {
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
  windowHeightScript = pkgs.writeShellApplication {
    name = "nagi-hyprland-window-height";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      current_height="$(hyprctl -j activewindow | jq -r '.size[1] // empty')"
      available_height="$(
        hyprctl -j monitors |
          jq -r '.[] | select(.focused) | ((.height / .scale) - .reserved[1] - .reserved[3]) | floor'
      )"

      [[ "$current_height" =~ ^[0-9]+$ && "$available_height" =~ ^[0-9]+$ ]] || exit 0

      if [[ "''${1:-cycle}" == reset ]]; then
        target_height="$available_height"
      else
        one_third="$((available_height / 3))"
        one_half="$((available_height / 2))"
        two_thirds="$(((available_height * 2) / 3))"

        if ((current_height >= one_third - 20 && current_height <= one_third + 20)); then
          target_height="$one_half"
        elif ((current_height >= one_half - 20 && current_height <= one_half + 20)); then
          target_height="$two_thirds"
        else
          target_height="$one_third"
        fi
      fi

      hyprctl dispatch resizeactive "0 $((target_height - current_height))"
    '';
  };
  noctalia = message: "${noctaliaCommand} msg ${message}";
in
''
  local mainMod = "SUPER"
  local layout = function(message) return hl.dsp.layout(message) end
  local scratchpadName = "scratchpad"
  local toggleScratchpad = hl.dsp.workspace.toggle_special(scratchpadName)
  local moveActiveWindowToScratchpad = hl.dsp.window.move({ workspace = "special:" .. scratchpadName })

  local function focusFirstColumn()
    for _ = 1, 64 do hl.dispatch(layout("move -col")) end
  end

  local function focusLastColumn()
    for _ = 1, 64 do hl.dispatch(layout("move +col")) end
    hl.dispatch(layout("move -col"))
  end

  local function moveColumnToEdge(direction)
    for _ = 1, 64 do hl.dispatch(layout("swapcol " .. direction)) end
  end

  local function switchFloatingFocus()
    local active = hl.get_active_window()
    local target = active ~= nil and active.floating and "tiled" or "floating"
    hl.dispatch(hl.dsp.focus({ window = target }))
  end

  local shortcutsInhibitDisabled = false
  local function toggleShortcutsInhibit()
    shortcutsInhibitDisabled = not shortcutsInhibitDisabled
    hl.config({ binds = { disable_keybind_grabbing = shortcutsInhibitDisabled } })
    hl.notification.create({
      text = shortcutsInhibitDisabled and "Application shortcut inhibition disabled" or "Application shortcut inhibition enabled",
      timeout = 1500,
      icon = 0,
    })
  end

  hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(${quote (noctalia "panel-toggle launcher")}), { description = "Launcher" })
  hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(${quote (noctalia "window-switcher")}), { description = "Window switcher" })
  hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd(${quote (noctalia "window-switcher")}), { description = "Window switcher" })
  hl.bind(mainMod .. " + SHIFT + slash", hl.dsp.exec_cmd("ghostty -e sh -lc 'hyprctl binds | less'"), { description = "Show keybinds" })

  hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("ghostty"), { description = "Open terminal" })
  hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"), { description = "Open terminal" })
  hl.bind(mainMod .. " + S", toggleScratchpad, { description = "Toggle scratchpad", dont_inhibit = true })
  hl.bind(mainMod .. " + SHIFT + S", moveActiveWindowToScratchpad, { description = "Move window to scratchpad", dont_inhibit = true })
  hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(${quote (noctalia "panel-toggle clipboard")}), { description = "Clipboard manager" })
  hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("ghostty -e htop"), { description = "Task manager" })
  hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("awakened-poe-trade"), { description = "Awakened PoE Trade", dont_inhibit = true })
  -- Price-check keys stay unbound so APT's globalShortcut handler runs.
  hl.bind(
    "SHIFT + Space",
    hl.dsp.pass({ window = "class:awakened-poe-trade" }),
    { description = "APT: toggle overlay", dont_inhibit = true }
  )
  hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"), { description = "File manager" })
  hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("zen"), { description = "Zen Browser" })
  hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd("mullvad-browser"), { description = "Mullvad Browser" })
  hl.bind("mouse:276", ${chatMuteAction}, { description = ${quote chatMuteDescription} })
  hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(${quote (noctalia "panel-toggle control-center")}), { description = "Control center" })

  hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(${quote (noctalia "volume-up")}), { locked = true, repeating = true })
  hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(${quote (noctalia "volume-down")}), { locked = true, repeating = true })
  hl.bind("XF86AudioMute", hl.dsp.exec_cmd(${quote (noctalia "volume-mute")}), { locked = true })
  hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(${quote (noctalia "brightness-up")}), { locked = true, repeating = true })
  hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(${quote (noctalia "brightness-down")}), { locked = true, repeating = true })

  hl.bind(mainMod .. " + Q", hl.dsp.window.close())
  hl.bind(mainMod .. " + F", layout("fit active"), { description = "Maximize column" })
  hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
  hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.float({ action = "toggle" }))
  hl.bind(mainMod .. " + SHIFT + V", switchFloatingFocus)
  hl.bind(mainMod .. " + W", hl.dsp.group.toggle(), { description = "Toggle tabbed group" })

  hl.bind(mainMod .. " + left", layout("focus l"))
  hl.bind(mainMod .. " + down", layout("focus d"))
  hl.bind(mainMod .. " + up", layout("focus u"))
  hl.bind(mainMod .. " + right", layout("focus r"))
  hl.bind(mainMod .. " + H", layout("focus l"))
  hl.bind(mainMod .. " + J", layout("focus d"))
  hl.bind(mainMod .. " + K", layout("focus u"))
  hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(${quote (noctalia "session lock")}))

  hl.bind(mainMod .. " + SHIFT + left", layout("swapcol l"))
  hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
  hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
  hl.bind(mainMod .. " + SHIFT + right", layout("swapcol r"))
  hl.bind(mainMod .. " + SHIFT + H", layout("swapcol l"))
  hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
  hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
  hl.bind(mainMod .. " + SHIFT + L", layout("swapcol r"))

  hl.bind(mainMod .. " + Home", focusFirstColumn)
  hl.bind(mainMod .. " + End", focusLastColumn)
  hl.bind(mainMod .. " + CTRL + Home", function() moveColumnToEdge("l") end)
  hl.bind(mainMod .. " + CTRL + End", function() moveColumnToEdge("r") end)

  hl.bind(mainMod .. " + CTRL + left", hl.dsp.focus({ monitor = "l" }))
  hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ monitor = "r" }))
  hl.bind(mainMod .. " + CTRL + H", hl.dsp.focus({ monitor = "l" }))
  hl.bind(mainMod .. " + CTRL + J", hl.dsp.focus({ monitor = "d" }))
  hl.bind(mainMod .. " + CTRL + K", hl.dsp.focus({ monitor = "u" }))
  hl.bind(mainMod .. " + CTRL + L", hl.dsp.focus({ monitor = "r" }))

  hl.bind(mainMod .. " + SHIFT + CTRL + left", hl.dsp.window.move({ monitor = "l" }))
  hl.bind(mainMod .. " + SHIFT + CTRL + down", hl.dsp.window.move({ monitor = "d" }))
  hl.bind(mainMod .. " + SHIFT + CTRL + up", hl.dsp.window.move({ monitor = "u" }))
  hl.bind(mainMod .. " + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "r" }))
  hl.bind(mainMod .. " + SHIFT + CTRL + H", hl.dsp.window.move({ monitor = "l" }))
  hl.bind(mainMod .. " + SHIFT + CTRL + J", hl.dsp.window.move({ monitor = "d" }))
  hl.bind(mainMod .. " + SHIFT + CTRL + K", hl.dsp.window.move({ monitor = "u" }))
  hl.bind(mainMod .. " + SHIFT + CTRL + L", hl.dsp.window.move({ monitor = "r" }))

  hl.bind(mainMod .. " + Page_Down", function() focusRelativeLocalWorkspace(1) end)
  hl.bind(mainMod .. " + Page_Up", function() focusRelativeLocalWorkspace(-1) end)
  hl.bind(mainMod .. " + U", function() focusRelativeLocalWorkspace(1) end)
  hl.bind(mainMod .. " + I", function() focusRelativeLocalWorkspace(-1) end)
  hl.bind(mainMod .. " + CTRL + down", function() focusRelativeLocalWorkspace(1) end)
  hl.bind(mainMod .. " + CTRL + up", function() focusRelativeLocalWorkspace(-1) end)
  hl.bind(mainMod .. " + CTRL + U", function() focusRelativeLocalWorkspace(1) end)
  hl.bind(mainMod .. " + CTRL + I", function() focusRelativeLocalWorkspace(-1) end)
  hl.bind("CTRL + SHIFT + R", hl.dsp.exec_cmd(${quote "${workspaceRenameScript}/bin/nagi-hyprland-rename-workspace"}), { description = "Rename workspace" })

  hl.bind(mainMod .. " + SHIFT + Page_Down", function() moveActiveWorkspaceRelative(1) end)
  hl.bind(mainMod .. " + SHIFT + Page_Up", function() moveActiveWorkspaceRelative(-1) end)
  hl.bind(mainMod .. " + SHIFT + U", function() moveActiveWorkspaceRelative(1) end)
  hl.bind(mainMod .. " + SHIFT + I", function() moveActiveWorkspaceRelative(-1) end)

  hl.bind(mainMod .. " + mouse_down", function() focusRelativeLocalWorkspace(1) end)
  hl.bind(mainMod .. " + mouse_up", function() focusRelativeLocalWorkspace(-1) end)
  hl.bind(mainMod .. " + CTRL + mouse_down", function() moveWindowToRelativeLocalWorkspace(1) end)
  hl.bind(mainMod .. " + CTRL + mouse_up", function() moveWindowToRelativeLocalWorkspace(-1) end)
  hl.bind(mainMod .. " + mouse_right", layout("focus r"))
  hl.bind(mainMod .. " + mouse_left", layout("focus l"))
  hl.bind(mainMod .. " + CTRL + mouse_right", layout("swapcol r"))
  hl.bind(mainMod .. " + CTRL + mouse_left", layout("swapcol l"))
  hl.bind(mainMod .. " + SHIFT + mouse_down", layout("focus r"))
  hl.bind(mainMod .. " + SHIFT + mouse_up", layout("focus l"))
  hl.bind(mainMod .. " + CTRL + SHIFT + mouse_down", layout("swapcol r"))
  hl.bind(mainMod .. " + CTRL + SHIFT + mouse_up", layout("swapcol l"))

  for i = 1, 9 do
    local slot = i
    hl.bind(mainMod .. " + " .. slot, function() focusLocalWorkspace(slot) end)
    hl.bind(mainMod .. " + SHIFT + " .. slot, function() moveWindowToLocalWorkspace(slot) end)
  end

  hl.bind(mainMod .. " + bracketleft", layout("consume_or_expel prev"))
  hl.bind(mainMod .. " + bracketright", layout("consume_or_expel next"))
  hl.bind(mainMod .. " + period", layout("promote"))

  hl.bind(mainMod .. " + R", layout("colresize +conf"))
  hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(${quote "${windowHeightScript}/bin/nagi-hyprland-window-height cycle"}))
  hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd(${quote "${windowHeightScript}/bin/nagi-hyprland-window-height reset"}))
  hl.bind(mainMod .. " + CTRL + F", layout("fit expand"), { description = "Expand into free space" })
  hl.bind(mainMod .. " + C", layout("center"))
  hl.bind(mainMod .. " + CTRL + C", layout("center"), { description = "Center visible columns (closest Hyprland equivalent)" })

  hl.bind(mainMod .. " + ALT + R", layout("fit_into_view"), { description = "Fit column into view" })
  hl.bind(mainMod .. " + ALT + F", layout("fit all"), { description = "Fit all columns" })
  hl.bind(mainMod .. " + ALT + I", layout("inhibit_scroll"), { description = "Toggle scrolling inhibition" })

  hl.bind(mainMod .. " + minus", layout("colresize -0.1"), { repeating = true })
  hl.bind(mainMod .. " + equal", layout("colresize +0.1"), { repeating = true })
  hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })
  hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true })

  local regionScreenshot = hl.dsp.exec_cmd(${quote "hyprshot -m region -z -o \"$HOME/Pictures/Screenshots\""})
  local outputScreenshot = hl.dsp.exec_cmd(${quote "hyprshot -m output -m active -o \"$HOME/Pictures/Screenshots\""})
  local windowScreenshot = hl.dsp.exec_cmd(${quote "hyprshot -m window -m active -o \"$HOME/Pictures/Screenshots\""})
  hl.bind("XF86Launch1", regionScreenshot)
  hl.bind("CTRL + XF86Launch1", outputScreenshot)
  hl.bind("ALT + XF86Launch1", windowScreenshot)
  hl.bind("Print", regionScreenshot)
  hl.bind("CTRL + Print", outputScreenshot)
  hl.bind("ALT + Print", windowScreenshot)

  hl.bind(mainMod .. " + Escape", toggleShortcutsInhibit, { dont_inhibit = true })
  hl.bind(mainMod .. " + SHIFT + P", hl.dsp.dpms({ action = "disable" }))

  hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
  hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
''
