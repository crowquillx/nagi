{
  lib,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  enabled =
    (get [ "security" "sops" "kotomi" "enable" ] true)
    && (get [ "features" "shell" "fish" "enable" ] true);
  targetSecret = "/run/secrets/kotomi_target";
in
{
  config = lib.mkIf enabled {
    # Reads the SSH jump target from sops at call time so the value
    # never appears in the fish config or shell history. Pass the
    # value as an explicit arg to `string trim`; with no args it
    # would read stdin and hang if the secret was empty/missing.
    programs.fish.functions.kotomi.body = ''
      if not test -r ${targetSecret}
        echo "kotomi: secret at ${targetSecret} is missing or unreadable" >&2
        return 1
      end
      set -l target (cat ${targetSecret})
      if test -z "$target"
        echo "kotomi: secret at ${targetSecret} is empty" >&2
        return 1
      end
      ssh (string trim -- "$target") $argv
    '';
  };
}