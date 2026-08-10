{
  lib,
  config,
  ...
}:
let
  v = config.nagi.variables;
  sopsEnabled = v.security.sops.enable;
  enabled = sopsEnabled && v.security.sops.kotomi.enable;
  primaryUser = v.users.primary;
  secretName = "kotomi_target";
in
{
  config = lib.mkIf enabled {
    # Materializes the SSH jump target string from the host's sops file
    # to /run/secrets/kotomi_target at activation time. The fish
    # `kotomi` function reads this file at call time, keeping the
    # target out of the public repo history.
    sops.secrets.${secretName} = {
      owner = primaryUser;
      group = "users";
      mode = "0400";
      path = "/run/secrets/${secretName}";
    };
  };
}
