{
  pkgs,
  config,
  ...
}:
let
  primaryUser = config.nagi.variables.users.primary;
in
{
  sops.secrets.pango_host = {
    owner = primaryUser;
    group = "users";
    mode = "0400";
  };

  programs.zsh.shellAliases.pango = "ssh tan@$(${pkgs.coreutils}/bin/cat /run/secrets/pango_host)";
}
