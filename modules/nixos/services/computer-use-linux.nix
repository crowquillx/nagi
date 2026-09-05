{
  lib,
  config,
  ...
}:
let
  v = config.nagi.variables;
  enabled = v.features.mcp.computerUseLinux.enable;
  inherit (v.desktop) compositor extraCompositors;
  compositors = [ compositor ] ++ extraCompositors;
  hasHyprland = builtins.elem "hyprland" compositors;
  hasPlasma = builtins.elem "plasma" compositors;
in
{
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = v.desktop.enable;
        message = "features.mcp.computerUseLinux.enable requires desktop.enable = true.";
      }
    ];

    warnings = lib.optional (!hasHyprland && !hasPlasma) ''
      features.mcp.computerUseLinux.enable is on, but this host has no Hyprland or
      Plasma session. computer-use-linux can still use AT-SPI, screenshots, and
      ydotool, but window listing and focus will not work.
    '';

    programs.dconf.enable = true;
    services.gnome.at-spi2-core.enable = true;

    boot.kernelModules = [ "uinput" ];
    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
    '';

    environment.sessionVariables = {
      NO_AT_BRIDGE = "0";
      GTK_A11Y = "atspi";
    };
  };
}
