{
  lib,
  config,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  codingToolsEnabled = get [ "features" "codingTools" "enable" ] true;
  editorsEnabled = get [ "features" "codingTools" "editors" "enable" ] codingToolsEnabled;
  t3codeEnabled = editorsEnabled && get [ "features" "codingTools" "editors" "t3code" "enable" ] true;
  t3ServiceEnabled =
    t3codeEnabled && get [ "features" "codingTools" "editors" "t3code" "service" "enable" ] true;
  primaryUser = v.users.primary;
in
{
  config = lib.mkIf t3ServiceEnabled {
    # The Home Manager unit is a user service. Linger keeps the user manager
    # (and t3 serve) up across logout and at boot, which KillUserProcesses
    # would otherwise tear down.
    users.users.${primaryUser}.linger = true;
  };
}
