{ lib, config, options, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  sessionEnabled = get [ "desktop" "session" "enable" ] desktopEnabled;
  keyringEnable = get [ "desktop" "session" "keyring" "enable" ] true;
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
