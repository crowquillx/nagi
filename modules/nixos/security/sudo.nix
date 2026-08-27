{
  lib,
  config,
  ...
}:
let
  passwordless = config.nagi.variables.security.sudo.passwordless;
in
{
  config = lib.mkIf passwordless {
    security.sudo.wheelNeedsPassword = false;
  };
}
