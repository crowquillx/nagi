{ lib, pkgs, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  secureBootEnabled = get [ "boot" "secureBoot" "enable" ] false;
  secureBootPkiBundle = get [ "boot" "secureBoot" "pkiBundle" ] "/var/lib/sbctl";
  secureBootAutoEnroll = get [ "boot" "secureBoot" "autoEnroll" ] false;
  secureBootIncludeMicrosoftKeys = get [ "boot" "secureBoot" "includeMicrosoftKeys" ] true;
in
{
  config = lib.mkIf secureBootEnabled {
    assertions = [
      {
        assertion = get [ "boot" "systemdBoot" "enable" ] true;
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
