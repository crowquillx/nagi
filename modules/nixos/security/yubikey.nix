{
  lib,
  pkgs,
  config,
  ...
}:
let
  enabled = config.nagi.variables.security.yubikey.enable;
in
{
  config = lib.mkIf enabled {
    # PC/SC smart card daemon — required for gpg-agent to talk to the
    # Yubikey's OpenPGP applet. CCID is included in NixOS's pcscd package.
    services.pcscd.enable = true;

    # udev rules for the Yubikey so non-root users (and the pcscd daemon)
    # can talk to it.
    services.udev.packages = [ pkgs.yubikey-manager ];
  };
}
