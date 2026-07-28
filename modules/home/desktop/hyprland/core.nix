{
  lib,
  vars,
  quote,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  outputs = get [ "desktop" "hyprland" "outputs" ] { };
  startup = import ../startup.nix { inherit lib vars; };
  noctaliaEnabled = get [ "desktop" "noctalia" "enable" ] false;
  noctaliaCommand = get [ "desktop" "noctalia" "command" ] "nagi-noctalia-shell";
  qtThemeEnabled =
    get [ "features" "stylix" "enable" ] true && get [ "features" "theme" "qt" "enable" ] true;
  nvidia = get [ "graphics" "profile" ] "auto" == "nvidia";
  cursorTheme = import ../cursor-theme.nix;

  mode =
    output:
    "${toString output.mode.width}x${toString output.mode.height}@${toString output.mode.refresh}";
  position =
    output:
    if output.position == null then
      "auto"
    else
      "${toString output.position.x}x${toString output.position.y}";
  transform =
    output:
    let
      value = output.transform;
      rotation = if builtins.isAttrs value then value.rotation or 0 else value;
      flipped = builtins.isAttrs value && (value.flipped or false);
      base =
        if rotation == 90 || rotation == "90" then
          1
        else if rotation == 180 || rotation == "180" then
          2
        else if rotation == 270 || rotation == "270" then
          3
        else
          0;
    in
    if flipped then base + 4 else base;
  vrr =
    value:
    if value == "on" then
      1
    else if value == "on-demand" then
      2
    else
      0;
  mkMonitor =
    name: output:
    if !(output.enable or true) then
      "hl.monitor({ output = ${quote name}, disabled = true })"
    else
      ''
        hl.monitor({
          output = ${quote name},
          mode = ${quote (mode output)},
          position = ${quote (position output)},
          scale = ${toString output.scale},
          transform = ${toString (transform output)},
          vrr = ${toString (vrr output.variableRefreshRate)},
          bitdepth = ${toString output.bitDepth},
          cm = ${quote output.colorManagement},
          sdrbrightness = ${toString output.sdrBrightness},
          sdrsaturation = ${toString output.sdrSaturation},
          sdr_max_luminance = ${toString output.sdrMaxLuminance},
        })
      '';
  monitorConfig = lib.concatStringsSep "\n" (lib.mapAttrsToList mkMonitor outputs);
  focusedOutputs = lib.attrNames (
    lib.filterAttrs (_: output: output.focusAtStartup or false) outputs
  );
  focusOutput = if focusedOutputs == [ ] then null else builtins.head focusedOutputs;
  startupCommands =
    lib.optionals noctaliaEnabled [ noctaliaCommand ]
    ++ lib.optionals (startup.startupBackend == "hyprland") startup.effectiveStartupApps;
  startupLua = lib.concatMapStringsSep "\n" (
    command: "  hl.exec_cmd(${quote command})"
  ) startupCommands;
in
''
  ${monitorConfig}

  hl.env("XCURSOR_SIZE", ${quote (toString cursorTheme.size)})
  hl.env("HYPRCURSOR_SIZE", ${quote (toString cursorTheme.size)})
  hl.env("NIXOS_OZONE_WL", "1")
  hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
  ${lib.optionalString qtThemeEnabled ''
    hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
    hl.env("QT_STYLE_OVERRIDE", "kvantum")
  ''}
  ${lib.optionalString nvidia ''
    hl.env("NVD_BACKEND", "direct")
  ''}

  hl.config({
    general = {
      gaps_in = 12,
      gaps_out = 12,
      border_size = 2,
      col = {
        active_border = "rgb(ebbcba)",
        inactive_border = "rgb(191724)",
      },
      layout = "scrolling",
      resize_on_border = true,
      allow_tearing = false,
      no_focus_fallback = true,
    },
    scrolling = {
      column_width = 0.5,
      explicit_column_widths = "0.33333, 0.5, 0.66667, 1.0",
      focus_fit_method = 1,
      follow_focus = true,
      follow_min_visible = 0.75,
      fullscreen_on_one_column = false,
      direction = "right",
      wrap_focus = false,
      wrap_swapcol = false,
    },
    input = {
      kb_layout = "us",
      numlock_by_default = true,
      follow_mouse = 1,
      sensitivity = 0,
      touchpad = {
        tap_to_click = true,
        natural_scroll = true,
      },
    },
    cursor = {
      hide_on_key_press = true,
    },
    decoration = {
      rounding = 12,
      rounding_power = 2,
      shadow = {
        enabled = true,
        range = 30,
        offset = { 0, 5 },
        render_power = 3,
        color = "rgba(19172470)",
      },
      blur = {
        enabled = true,
        size = 3,
        passes = 2,
        noise = 0.03,
        vibrancy = 0.0,
        xray = false,
      },
    },
    animations = {
      enabled = true,
    },
    binds = {
      scroll_event_delay = 150,
      window_direction_monitor_fallback = false,
    },
    xwayland = {
      force_zero_scaling = true,
    },
    render = {
      cm_enabled = true,
      cm_auto_hdr = 1,
    },
    misc = {
      disable_hyprland_logo = true,
      disable_splash_rendering = true,
      focus_on_activate = true,
    },
  })

  -- Match niri: workspaces stack vertically.
  hl.animation({ leaf = "workspaces", enabled = true, speed = 8, bezier = "default", style = "slidevert" })

  hl.on("hyprland.start", function()
  ${startupLua}
  ${lib.optionalString (
    focusOutput != null
  ) "  hl.dispatch(hl.dsp.focus({ monitor = ${quote focusOutput} }))"}
  end)

  ${lib.optionalString noctaliaEnabled ''
    hl.layer_rule({
      name = "noctalia",
      match = {
        namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
      },
      no_anim = true,
      ignore_alpha = 0.5,
      blur = true,
      blur_popups = true,
    })
  ''}
''
