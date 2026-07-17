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
    # never appears in the fish config, shell history, or ssh argv
    # (/proc/<pid>/cmdline). The destination is applied via a 0600
    # ssh config (HostName/User); argv only sees the local alias.
    # Trim before the empty check so whitespace-only secrets fail closed.
    programs.fish.functions.kotomi.body = ''
      if not test -r ${targetSecret}
        echo "kotomi: secret at ${targetSecret} is missing or unreadable" >&2
        return 1
      end

      set -l target (string trim -- (cat ${targetSecret}))
      if test -z "$target"
        echo "kotomi: secret at ${targetSecret} is empty" >&2
        return 1
      end

      set -l cfg_dir $XDG_RUNTIME_DIR
      if test -z "$cfg_dir"; or not test -d "$cfg_dir"
        set cfg_dir /tmp
      end

      set -l cfg (mktemp -p "$cfg_dir" kotomi.XXXXXX)
      or begin
        echo "kotomi: failed to create temp ssh config" >&2
        return 1
      end
      chmod 0600 -- $cfg
      or begin
        rm -f -- $cfg
        echo "kotomi: failed to restrict temp ssh config permissions" >&2
        return 1
      end

      # Prefer the secret HostName/User over anything in included configs
      # (ssh first-wins). Include user/system configs afterward so normal
      # IdentityFile and Host * options still apply under -F.
      if string match -q -- '*@*' $target
        set -l user (string split -m 1 @ -- $target)[1]
        set -l host (string split -m 1 @ -- $target)[2]
        printf 'Host kotomi\n  User %s\n  HostName %s\nInclude ~/.ssh/config\nInclude /etc/ssh/ssh_config\n' $user $host >$cfg
      else
        printf 'Host kotomi\n  HostName %s\nInclude ~/.ssh/config\nInclude /etc/ssh/ssh_config\n' $target >$cfg
      end
      or begin
        rm -f -- $cfg
        echo "kotomi: failed to write temp ssh config" >&2
        return 1
      end

      command ssh -F $cfg kotomi $argv
      set -l st $status
      rm -f -- $cfg
      return $st
    '';
  };
}
