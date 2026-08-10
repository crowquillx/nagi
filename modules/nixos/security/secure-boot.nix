{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  secureBootEnabled = v.boot.secureBoot.enable;
  secureBootPkiBundle = v.boot.secureBoot.pkiBundle;
  secureBootAutoEnroll = v.boot.secureBoot.autoEnroll;
  secureBootIncludeMicrosoftKeys = v.boot.secureBoot.includeMicrosoftKeys;
in
{
  config = lib.mkIf secureBootEnabled {
    assertions = [
      {
        assertion = v.boot.systemdBoot.enable;
        message = "boot.secureBoot.enable requires boot.systemdBoot.enable = true during setup/migration.";
      }
    ];

    # Lanzaboote replaces direct systemd-boot management once enabled.
    boot.loader.systemd-boot.enable = lib.mkForce false;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = secureBootPkiBundle;
      autoEnrollKeys = {
        enable = secureBootAutoEnroll;
        includeMicrosoftKeys = secureBootIncludeMicrosoftKeys;
      };
    };

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
