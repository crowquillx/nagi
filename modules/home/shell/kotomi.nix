{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  secretEnabled = get [ "security" "sops" "kotomi" "enable" ] true;
  fishEnabled = get [ "features" "shell" "fish" "enable" ] true;
  zshEnabled = get [ "features" "shell" "zsh" "enable" ] false;
  targetSecret = "/run/secrets/kotomi_target";
in
{
  config = lib.mkIf (secretEnabled && (fishEnabled || zshEnabled)) {
    # Reads the SSH jump target from sops at call time so the value never
    # appears in shell config, history, or ssh argv (/proc/<pid>/cmdline).
    programs = {
      fish.functions.kotomi.body = lib.mkIf fishEnabled ''
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

      zsh.initContent = lib.mkIf zshEnabled ''
        kotomi() {
          if [[ ! -r ${targetSecret} ]]; then
            echo "kotomi: secret at ${targetSecret} is missing or unreadable" >&2
            return 1
          fi

          local target
          target="$(${pkgs.coreutils}/bin/cat ${targetSecret} | ${pkgs.gnused}/bin/sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
          if [[ -z "$target" ]]; then
            echo "kotomi: secret at ${targetSecret} is empty" >&2
            return 1
          fi

          local cfg_dir="''${XDG_RUNTIME_DIR:-/tmp}"
          if [[ ! -d "$cfg_dir" ]]; then
            cfg_dir=/tmp
          fi

          local cfg
          cfg="$(${pkgs.coreutils}/bin/mktemp -p "$cfg_dir" kotomi.XXXXXX)" || {
            echo "kotomi: failed to create temp ssh config" >&2
            return 1
          }
          ${pkgs.coreutils}/bin/chmod 0600 -- "$cfg" || {
            ${pkgs.coreutils}/bin/rm -f -- "$cfg"
            echo "kotomi: failed to restrict temp ssh config permissions" >&2
            return 1
          }

          if [[ "$target" == *@* ]]; then
            local user="''${target%%@*}"
            local host="''${target#*@}"
            printf 'Host kotomi\n  User %s\n  HostName %s\nInclude ~/.ssh/config\nInclude /etc/ssh/ssh_config\n' "$user" "$host" >"$cfg"
          else
            printf 'Host kotomi\n  HostName %s\nInclude ~/.ssh/config\nInclude /etc/ssh/ssh_config\n' "$target" >"$cfg"
          fi || {
            ${pkgs.coreutils}/bin/rm -f -- "$cfg"
            echo "kotomi: failed to write temp ssh config" >&2
            return 1
          }

          command ssh -F "$cfg" kotomi "$@"
          local exit_status=$?
          ${pkgs.coreutils}/bin/rm -f -- "$cfg"
          return "$exit_status"
        }
      '';
    };
  };
}
