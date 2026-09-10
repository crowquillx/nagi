{
  lib,
  config,
  ...
}:
let
  v = config.nagi.variables;
  enabled = v.features.mcp.computerUseLinux.enable;
in
{
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = v.desktop.enable;
        message = "features.mcp.computerUseLinux.enable requires desktop.enable = true.";
      }
    ];

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
