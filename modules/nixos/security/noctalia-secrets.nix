{
  lib,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  primaryUser = get [ "users" "primary" ] "nagi";
  desktopEnabled = get [ "desktop" "enable" ] true;
  noctaliaEnabled = get [ "desktop" "noctalia" "enable" ] desktopEnabled;
  secrets = get [ "desktop" "noctalia" "assistantPanel" "secrets" ] { };

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
