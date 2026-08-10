{
  lib,
  pkgs,
  config,
  ...
}:
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

  networking.hostName = get [ "host" "name" ] "tanlappy";

  sops.secrets.pango_host = {
    owner = primaryUser;
    group = "users";
    mode = "0400";
  };

  programs.zsh.shellAliases.pango = "ssh tan@$(${pkgs.coreutils}/bin/cat /run/secrets/pango_host)";
}
