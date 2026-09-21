{
  animation = {
    curve = "easeout";
    duration_ms = 250;
    enabled = true;
    overview = {
      curve = "easeout";
      duration_ms = 250;
      enabled = true;
    };
    scratchpad = {
      blur = false;
      curve = "easeout";
      dim = 0.5;
      duration_ms = 250;
      enabled = true;
      fullscreen = false;
      maximize = false;
      scale = 0;
    };
    windows_in = {
      curve = "easeout";
      duration_ms = 150;
      enabled = true;
      scale = 0.85;
      style = "popin";
    };
    windows_move = {
      curve = "snappy";
      duration_ms = 250;
      enabled = true;
    };
    windows_out = {
      curve = "easeout";
      duration_ms = 150;
      enabled = true;
      style = "fade";
    };
    workspaces = {
      curve = "easeout";
      duration_ms = 250;
      enabled = true;
    };
  };
  appearance = {
    blur = {
      brightness = 1;
      contrast = 1;
      enabled = true;
      noise = 0.03;
      optimized = false;
      passes = 2;
      radius = 3;
      saturation = 1;
    };
    border_width = 2;
    corner_radius = 12;
    drag_opacity = 0.75;
    outer_border_width = 0;
    prefer_no_csd = true;
    shadow = {
      enabled = true;
      offset_x = 0;
      offset_y = 5;
      softness = 30;
    };
  };
  colors = {
    accent_primary = "#EBBCBAFF";
    accent_secondary = "#F6C177FF";
    backdrop = "#191724FF";
    background = "#191724FF";
    border = {
      focused = "#EBBCBAFF";
      outer = "#191724FF";
      scratchpad_focused = "#F6C177FF";
      scratchpad_unfocused = "#6E6A86FF";
      unfocused = "#191724FF";
    };
    error = "#EB6F92FF";
    insert_hint = "#EBBCBA80";
    overview = {
      background_tint = "#19172430";
      badge = "#EBBCBAFF";
      workspace_background = "#19172444";
    };
    shadow = "#19172470";
    text_muted = "#6E6A86FF";
    text_primary = "#E0DEF4FF";
    warning = "#F6C177FF";
  };
  environment = {
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORMTHEME = "qt5ct";
    QT_STYLE_OVERRIDE = "kvantum";
  };
  general = {
    autostart = [ ];
    focus_on_activate = true;
    honor_restored_maximize = false;
    mod_key = "Super";
    show_cheatsheet = false;
    xwayland = true;
  };
  hot_corners = {
    bottom_left = {
      action = "overview-toggle";
      delay_ms = 500;
      enabled = false;
    };
    bottom_right = {
      action = "overview-toggle";
      delay_ms = 500;
      enabled = false;
    };
    top_left = {
      action = "overview-open";
      delay_ms = 500;
      enabled = false;
    };
    top_right = {
      action = "overview-close";
      delay_ms = 500;
      enabled = false;
    };
  };
  include = {
    files = [ ];
    optional = {
      files = [ "noctalia.toml" ];
    };
  };
  input = {
    cursor = {
      follows_focus = false;
      hardware_cursor = true;
      hide_timeout_ms = 0;
      hide_when_typing = true;
      size = 32;
      theme = "BreezeX-RosePine-Linux";
    };
    focus = {
      follows_mouse = true;
      follows_mouse_max_scroll = 0.15;
    };
    keyboard = {
      layout = "";
      numlock_toggle = true;
      options = "";
      repeat_delay = 600;
      repeat_rate = 25;
      track_layout = "global";
      variant = "";
    };
    middle_click_paste = true;
    mouse = {
      scroll_wheel_step = 60;
      sensitivity = 0;
    };
    touchpad = {
      natural_scroll = true;
      tap = true;
    };
    window_drag_toggle = "none";
  };
  keybinds = {
    "Alt+Print" = "spawn:nagi-noctalia-shell msg screenshot-window";
    "Ctrl+Print" = "spawn:nagi-noctalia-shell msg screenshot-fullscreen";
    "Mod+1" = "workspace-switch:1";
    "Mod+2" = "workspace-switch:2";
    "Mod+3" = "workspace-switch:3";
    "Mod+4" = "workspace-switch:4";
    "Mod+5" = "workspace-switch:5";
    "Mod+6" = "workspace-switch:6";
    "Mod+7" = "workspace-switch:7";
    "Mod+8" = "workspace-switch:8";
    "Mod+9" = "workspace-switch:9";
    "Mod+Alt+Left" = "layout-scroll-left";
    "Mod+Alt+P" = "spawn:awakened-poe-trade";
    "Mod+Alt+Right" = "layout-scroll-right";
    "Mod+BracketLeft" = "window-consume-or-expel-left";
    "Mod+BracketRight" = "window-consume-or-expel-right";
    "Mod+C" = "column-center";
    "Mod+Comma" = "spawn:nagi-noctalia-shell msg settings-toggle";
    "Mod+Ctrl+Down" = "workspace-next";
    "Mod+Ctrl+End" = "column-move-to-last";
    "Mod+Ctrl+F" = "window-set-primary-extent:1.0";
    "Mod+Ctrl+Home" = "column-move-to-first";
    "Mod+Ctrl+I" = "workspace-previous";
    "Mod+Ctrl+R" = "window-set-secondary-extent:1.0";
    "Mod+Ctrl+S" = "window-restore-from-scratchpad";
    "Mod+Ctrl+Shift+WheelDown" = "column-move-right";
    "Mod+Ctrl+Shift+WheelUp" = "column-move-left";
    "Mod+Ctrl+Tab" = "scratchpad-focus-next";
    "Mod+Ctrl+U" = "workspace-next";
    "Mod+Ctrl+Up" = "workspace-previous";
    "Mod+Ctrl+WheelDown" = "column-move-to-workspace-next";
    "Mod+Ctrl+WheelLeft" = "column-move-left";
    "Mod+Ctrl+WheelRight" = "column-move-right";
    "Mod+Ctrl+WheelUp" = "column-move-to-workspace-previous";
    "Mod+D" = "spawn:nagi-noctalia-shell msg panel-toggle launcher";
    "Mod+Down" = "window-focus-down";
    "Mod+End" = "column-focus-last";
    "Mod+Equal" = "window-modify-primary-extent:0.1";
    "Mod+F" = "window-toggle-maximize";
    "Mod+H" = "window-focus-left";
    "Mod+Home" = "column-focus-first";
    "Mod+I" = "workspace-previous";
    "Mod+J" = "window-focus-down";
    "Mod+K" = "window-focus-up";
    "Mod+L" = "spawn:nagi-noctalia-shell msg session lock";
    "Mod+Left" = "window-focus-left";
    "Mod+M" = "spawn:ghostty -e htop";
    "Mod+Minus" = "window-modify-primary-extent:-0.1";
    "Mod+N" = "spawn:nagi-noctalia-shell msg panel-toggle control-center notifications";
    "Mod+Page_Down" = "workspace-next";
    "Mod+Page_Up" = "workspace-previous";
    "Mod+Q" = "window-close";
    "Mod+R" = "window-cycle-primary-extent";
    "Mod+Return" = "spawn:ghostty";
    "Mod+Right" = "window-focus-right";
    "Mod+S" = "scratchpad-toggle";
    "Mod+Shift+1" = "column-move-to-workspace:1";
    "Mod+Shift+2" = "column-move-to-workspace:2";
    "Mod+Shift+3" = "column-move-to-workspace:3";
    "Mod+Shift+4" = "column-move-to-workspace:4";
    "Mod+Shift+5" = "column-move-to-workspace:5";
    "Mod+Shift+6" = "column-move-to-workspace:6";
    "Mod+Shift+7" = "column-move-to-workspace:7";
    "Mod+Shift+8" = "column-move-to-workspace:8";
    "Mod+Shift+9" = "column-move-to-workspace:9";
    "Mod+Shift+Down" = "window-move-down";
    "Mod+Shift+Equal" = "window-modify-secondary-extent:0.1";
    "Mod+Shift+Escape" = "spawn:nagi-restart-shell";
    "Mod+Shift+F" = "window-toggle-fullscreen";
    "Mod+Shift+H" = "column-move-left";
    "Mod+Shift+I" = "workspace-move-up";
    "Mod+Shift+J" = "window-move-down";
    "Mod+Shift+K" = "window-move-up";
    "Mod+Shift+L" = "column-move-right";
    "Mod+Shift+Left" = "column-move-left";
    "Mod+Shift+Minus" = "window-modify-secondary-extent:-0.1";
    "Mod+Shift+P" = "dpms-off";
    "Mod+Shift+Page_Down" = "workspace-move-down";
    "Mod+Shift+Page_Up" = "workspace-move-up";
    "Mod+Shift+R" = "window-cycle-secondary-extent";
    "Mod+Shift+Right" = "column-move-right";
    "Mod+Shift+S" = "window-move-to-scratchpad";
    "Mod+Shift+Slash" = "cheatsheet-toggle";
    "Mod+Shift+T" = "window-toggle-floating";
    "Mod+Shift+U" = "workspace-move-down";
    "Mod+Shift+Up" = "window-move-up";
    "Mod+Shift+V" = "window-focus-switch-floating";
    "Mod+Shift+WheelDown" = "window-focus-right";
    "Mod+Shift+WheelUp" = "window-focus-left";
    "Mod+Shift+Z" = "spawn:mullvad-browser";
    "Mod+Space" = {
      action = "overview-toggle";
      repeat = false;
    };
    "Mod+T" = "spawn:kitty";
    "Mod+Tab" = {
      action = "overview-toggle";
      repeat = false;
    };
    "Mod+U" = "workspace-next";
    "Mod+Up" = "window-focus-up";
    "Mod+V" = "spawn:nagi-noctalia-shell msg panel-toggle clipboard";
    "Mod+WheelDown" = {
      action = "workspace-next";
      cooldown_ms = 150;
    };
    "Mod+WheelLeft" = "window-focus-left";
    "Mod+WheelRight" = "window-focus-right";
    "Mod+WheelUp" = {
      action = "workspace-previous";
      cooldown_ms = 150;
    };
    "Mod+Y" = "spawn:nagi-noctalia-shell msg panel-toggle wallpaper";
    "Mod+Z" = "spawn:zen-beta";
    Print = "spawn:nagi-noctalia-shell msg screenshot-region";
    "Super+B" = "spawn:nagi-noctalia-shell msg panel-toggle control-center";
    "Super+E" = "spawn:thunar";
    XF86AudioLowerVolume = "spawn:nagi-noctalia-shell msg volume-down";
    XF86AudioMute = "spawn:nagi-noctalia-shell msg volume-mute";
    XF86AudioRaiseVolume = "spawn:nagi-noctalia-shell msg volume-up";
    XF86MonBrightnessDown = "spawn:nagi-noctalia-shell msg brightness-down";
    XF86MonBrightnessUp = "spawn:nagi-noctalia-shell msg brightness-up";
  };
  layer_rule = [
    {
      blur = true;
      blur_ignore_alpha = 0.5;
      blur_optimized = false;
      blur_popups = true;
      match = {
        namespace = "^noctalia-(bar-[^\\\"]+|notification|dock|panel|attached-panel|osd|desktop-widget-[^\\\"]*)$";
      };
    }
  ];
  layout = {
    extent_presets = [
      0.33333
      0.5
      0.66667
    ];
    gap = 12;
    mode = "scrolling";
    scrolling = {
      center_focused = "never";
      center_underfull_strip = true;
      default_extent_fraction = 0.5;
    };
    struts = {
      bottom = 0;
      left = 0;
      right = 0;
      top = 0;
    };
  };
  overview = {
    zoom = 0.5;
  };
  window_rule = [
    {
      blur = true;
      blur_optimized = false;
    }
    {
      default_floating = true;
      default_floating_size_px = {
        height = 920;
        width = 1080;
      };
      match = {
        app_id = "^dev[.]noctalia[.]Noctalia([.]Settings)?$";
      };
    }
    {
      default_floating = true;
      default_pinned = true;
      default_position = {
        anchor = "bottom_right";
        x = 20;
        y = 20;
      };
      match = {
        title = "^(Picture-in-Picture|Picture in picture)$";
      };
    }
    {
      default_focused = false;
      default_pinned = true;
      default_position = {
        anchor = "bottom_right";
        x = 0;
        y = 0;
      };
      match = {
        title = "^notificationtoasts_.+_desktop";
      };
    }
    {
      match = {
        app_id = "^(org[.]wezfurlong[.]wezterm|wezterm|t3code|com[.]t3tools[.]T3Code|com[.]mitchellh[.]ghostty|ghostty|kitty|Alacritty|alacritty|foot|org[.]gnome[.]Console|kgx|app[.]devsuite[.]Ptyxis|org[.]gnome[.]Ptyxis|ptyxis|org[.]kde[.]konsole|konsole|org[.]gnome[.]Terminal|gnome-terminal|terminator|com[.]github[.]gnunn1[.]tilix|tilix|xterm|uxterm|thunar|org[.]xfce[.]Thunar|org[.]gnome[.]FileRoller|org[.]kde[.]dolphin|dolphin|org[.]gnome[.]Nautilus|nautilus|nemo|org[.]nemo[.]Nemo|pcmanfm|pcmanfm-qt|org[.]lxde[.]PCManFM|org[.]lxqt[.]pcmanfm-qt|org[.]kde[.]krusader|krusader|equibop|vesktop|dev[.]vencord[.]Vesktop|discord|com[.]discordapp[.]Discord|org[.]telegram[.]desktop|telegram-desktop|element|im[.]riot[.]Riot|comet|org[.]gnome[.]Fractal|fractal|codex-desktop|ChatGPT|code|code-url-handler|com[.]visualstudio[.]code|code-oss|codium|vscodium|cursor|zed|dev[.]zed[.]Zed|t3-code|T3 Code.*|windsurf|jetbrains-.*|android-studio|neovide|emacs|micro|orca|spotify|electron)$";
      };
      opacity = 0.9;
    }
    {
      match = {
        app_id = "^(org[.]wezfurlong[.]wezterm|wezterm|t3code|com[.]t3tools[.]T3Code|com[.]mitchellh[.]ghostty|ghostty|kitty|Alacritty|alacritty|foot|org[.]gnome[.]Console|kgx|app[.]devsuite[.]Ptyxis|org[.]gnome[.]Ptyxis|ptyxis|org[.]kde[.]konsole|konsole|org[.]gnome[.]Terminal|gnome-terminal|terminator|com[.]github[.]gnunn1[.]tilix|tilix|xterm|uxterm|thunar|org[.]xfce[.]Thunar|org[.]gnome[.]FileRoller|org[.]kde[.]dolphin|dolphin|org[.]gnome[.]Nautilus|nautilus|nemo|org[.]nemo[.]Nemo|pcmanfm|pcmanfm-qt|org[.]lxde[.]PCManFM|org[.]lxqt[.]pcmanfm-qt|org[.]kde[.]krusader|krusader|equibop|vesktop|dev[.]vencord[.]Vesktop|discord|com[.]discordapp[.]Discord|org[.]telegram[.]desktop|telegram-desktop|element|im[.]riot[.]Riot|comet|org[.]gnome[.]Fractal|fractal|codex-desktop|ChatGPT|code|code-url-handler|com[.]visualstudio[.]code|code-oss|codium|vscodium|cursor|zed|dev[.]zed[.]Zed|t3-code|T3 Code.*|windsurf|jetbrains-.*|android-studio|neovide|emacs|micro|orca|spotify|electron)$";
        is_focused = true;
      };
      opacity = 0.96;
    }
    {
      default_floating = true;
      match = {
        app_id = "^(thunar|org[.]gnome[.]FileRoller)$";
      };
    }
    {
      default_floating = true;
      match = {
        app_id = "^steam$";
      };
    }
    {
      default_floating = false;
      default_maximize = true;
      match = {
        app_id = "^steam$";
        title = "^Steam$";
      };
    }
  ];
  workspaces = {
    back_and_forth = false;
    empty_above = false;
  };
}
