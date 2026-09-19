{ lib, config, ... }:
let
  v = config.nagi.variables;
in
{
  config = lib.mkIf v.features.chat.discord.mouseMute.enable {
    hardware.uinput.enable = true;
    users.users.${v.users.primary}.extraGroups = [ "uinput" ];
  };
}
