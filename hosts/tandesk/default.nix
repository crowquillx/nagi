{ lib, pkgs, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  primaryUser = get [ "users" "primary" ] "nagi";
in
{
  imports = [
    ../common/default.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = get [ "host" "name" ] "tandesk";

  sops.secrets.pango_host = {
    owner = primaryUser;
    group = "users";
    mode = "0400";
  };

  programs.fish.shellAliases.pango =
    "ssh tan@(${pkgs.coreutils}/bin/cat /run/secrets/pango_host)";

  services.logind.settings = {
    Login = {
      HandlePowerKey = "poweroff";
      HandleSuspendKey = "ignore";
      HandleHibernateKey = "ignore";
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
  };

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
