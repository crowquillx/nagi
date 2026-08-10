{
  lib,
  config,
  options,
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

    security.pam.services = lib.mkMerge [
      (lib.mkIf (options.security.pam.services ? login) {
        login.enableGnomeKeyring = true;
      })
      (lib.mkIf (options.security.pam.services ? sddm) {
        sddm.enableGnomeKeyring = true;
      })
    ];
  };
}
