{
  lib,
  config,
  ...
}:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
  sessionEnabled = v.desktop.session.enable;
  keyringEnable = v.desktop.session.keyring.enable;
in
{
  config = lib.mkIf (desktopEnabled && sessionEnabled && keyringEnable) {
    services.gnome.gnome-keyring.enable = true;

    security.pam.services = {
      login.enableGnomeKeyring = true;
      greetd.enableGnomeKeyring = true;
    };
  };
}
