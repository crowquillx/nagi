{ lib, vars, ... }:
let
  isTandesk = (vars.host.name or "") == "tandesk";
in
''
  hl.window_rule({
    name = "picture-in-picture",
    match = {
      class = "(?i)^(zen|zen-beta|mullvad-browser|Mullvad Browser)$",
      title = "^Picture-in-Picture$",
    },
    float = true,
    pin = true,
  })

  hl.window_rule({
    name = "noctalia-settings",
    match = { class = "^dev\\.noctalia\\.Noctalia(\\.Settings)?$" },
    float = true,
    size = { 1080, 920 },
    center = true,
  })

  hl.window_rule({
    name = "transparent-apps",
    match = {
      class = "(?i)^(org\\.wezfurlong\\.wezterm|wezterm|t3code|com\\.mitchellh\\.ghostty|ghostty|kitty|Alacritty|alacritty|foot|org\\.gnome\\.Console|kgx|app\\.devsuite\\.Ptyxis|org\\.gnome\\.Ptyxis|ptyxis|org\\.kde\\.konsole|konsole|org\\.gnome\\.Terminal|gnome-terminal|terminator|com\\.github\\.gnunn1\\.tilix|tilix|xterm|uxterm|thunar|org\\.xfce\\.Thunar|org\\.gnome\\.FileRoller|org\\.kde\\.dolphin|dolphin|org\\.gnome\\.Nautilus|nautilus|nemo|org\\.nemo\\.Nemo|pcmanfm|pcmanfm-qt|org\\.lxde\\.PCManFM|org\\.lxqt\\.pcmanfm-qt|org\\.kde\\.krusader|krusader|equibop|vesktop|dev\\.vencord\\.Vesktop|discord|com\\.discordapp\\.Discord|org\\.telegram\\.desktop|telegram-desktop|element|im\\.riot\\.Riot|comet|org\\.gnome\\.Fractal|fractal|codex-desktop|ChatGPT|code|code-url-handler|com\\.visualstudio\\.code|code-oss|codium|vscodium|cursor|zed|dev\\.zed\\.Zed|t3-code|T3 Code.*|windsurf|jetbrains-.*|android-studio|neovide|emacs|micro|orca|spotify|electron)$",
    },
    opacity = "0.96 override 0.90 override",
  })

  -- APT is forced to XWayland by its package wrapper. PoE uses its in-game
  -- Windowed Fullscreen mode; Hyprland keeps that window full-monitor.
  hl.window_rule({
    name = "apt",
    match = { class = "awakened-poe-trade" },
    ${lib.optionalString isTandesk ''monitor = "DP-3",''}
    float = true,
    no_blur = true,
    no_shadow = true,
    border_size = 0,
  })

  hl.window_rule({
    name = "path-of-exile",
    match = { class = "^(steam_app_238960|steam_app_2694490)$" },
    float = true,
    fullscreen = true,
    border_size = 0,
    content = "game",
  })

  hl.window_rule({
    name = "file-tools",
    match = { class = "(?i)^(thunar|org\\.gnome\\.FileRoller)$" },
    float = true,
    min_size = { 450, 225 },
  })

  hl.window_rule({
    name = "steam-popups",
    match = { class = "(?i)^steam$" },
    float = true,
  })

  hl.window_rule({
    name = "steam-main",
    match = {
      class = "(?i)^steam$",
      title = "^Steam$",
    },
    float = false,
    maximize = true,
  })

  ${
    if isTandesk then
      ''
        hl.window_rule({
          name = "tandesk-chat",
          match = { class = "(?i)^(discord|com\\.discordapp\\.Discord|equibop)$" },
          monitor = "DP-1",
          maximize = true,
        })

        hl.window_rule({
          name = "tandesk-discord-electron",
          match = {
            class = "(?i)^electron$",
            title = "(?i)^.*discord.*$",
          },
          monitor = "DP-1",
          maximize = true,
        })

        hl.window_rule({
          name = "tandesk-spotify",
          match = { class = "(?i)^spotify$" },
          monitor = "DP-2",
          maximize = true,
        })
      ''
    else
      ""
  }
''
