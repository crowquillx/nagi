{
  lib,
  config,
  ...
}:
let
  v = config.nagi.variables;
  primaryUser = v.users.primary;
  noctaliaEnabled = v.desktop.enable && v.desktop.noctalia.enable;
  secrets = v.desktop.noctalia.assistantPanel.secrets;

  mkSecret =
    name:
    lib.nameValuePair name {
      owner = primaryUser;
      group = "users";
      mode = "0400";
      path = "/run/secrets/${name}";
    };

  configuredSecretNames = builtins.filter (name: lib.isString name && name != "") [
    (secrets.googleApiKey or "")
    (secrets.openaiCompatibleApiKey or "")
    (secrets.deeplApiKey or "")
  ];
in
{
  config = lib.mkIf (noctaliaEnabled && configuredSecretNames != [ ]) {
    sops.secrets = builtins.listToAttrs (map mkSecret configuredSecretNames);
  };
}
