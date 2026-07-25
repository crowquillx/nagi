{
  lib,
  pkgs,
  vars ? { },
  config,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasNoctaliaCompositor = builtins.any (
    candidate:
    builtins.elem candidate [
      "niri"
      "hyprland"
    ]
  ) ([ compositor ] ++ extraCompositors);
  noctaliaEnabled = get [ "desktop" "noctalia" "enable" ] (desktopEnabled && hasNoctaliaCompositor);
  secrets = get [ "desktop" "noctalia" "assistantPanel" "secrets" ] { };

  mkSecretPath = name: if lib.isString name && name != "" then "/run/secrets/${name}" else null;

  googleApiKeyPath = mkSecretPath (secrets.googleApiKey or "");
  openaiCompatibleApiKeyPath = mkSecretPath (secrets.openaiCompatibleApiKey or "");
  deeplApiKeyPath = mkSecretPath (secrets.deeplApiKey or "");

  exportSecret =
    envName: secretPath:
    lib.optionalString (secretPath != null) ''
      if [ -r ${lib.escapeShellArg secretPath} ]; then
        export ${envName}="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg secretPath})"
      fi
    '';

  noctaliaCommandWrapper = pkgs.writeShellScriptBin "nagi-noctalia-shell" ''
    set -eu

    ${exportSecret "NOCTALIA_AP_GOOGLE_API_KEY" googleApiKeyPath}
    ${exportSecret "NOCTALIA_AP_OPENAI_COMPATIBLE_API_KEY" openaiCompatibleApiKeyPath}
    ${exportSecret "NOCTALIA_AP_DEEPL_API_KEY" deeplApiKeyPath}

    exec noctalia "$@"
  '';
in
{
  config = lib.mkIf (desktopEnabled && hasNoctaliaCompositor && noctaliaEnabled) {
    home.packages = [ noctaliaCommandWrapper ];
  };
}
