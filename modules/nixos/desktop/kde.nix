{ lib, config, ... }:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
  inherit (v.desktop) compositor extraCompositors;
  hasPlasma = builtins.elem "plasma" ([ compositor ] ++ extraCompositors);
in
{
  config = lib.mkIf (desktopEnabled && hasPlasma) {
    services.desktopManager.plasma6.enable = true;
  };
}
