{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  enabled = get [ "features" "ssh" "autoTmux" "enable" ] false;
  zshEnabled = get [ "features" "shell" "zsh" "enable" ] false;
  sessionName = get [ "features" "ssh" "autoTmux" "sessionName" ] "ssh";
  # Absolute runtime socket. Using -L + TMUX_TMPDIR is racy after reboot:
  # linger can start the service before the graphical session exports
  # TMUX_TMPDIR=/run/user/..., leaving the server on /tmp while SSH clients
  # look under $XDG_RUNTIME_DIR and spawn a disposable second server.
  inherit (pkgs) coreutils;
  tmux = "${pkgs.tmux}/bin/tmux";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  tmuxSsh = pkgs.writeShellApplication {
    name = "tmux-ssh";
    runtimeInputs = [
      coreutils
      pkgs.tmux
    ];
    text = ''
      set -euo pipefail
      sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nagi-ssh.sock"
      exec tmux -S "$sock" "$@"
    '';
  };
  attachTmuxFish = ''
    if set -q SSH_TTY; and not set -q TMUX
      ${systemctl} --user start nagi-ssh-tmux.service
      set -l sock /run/user/(${coreutils}/bin/id -u)/nagi-ssh.sock
      if set -q XDG_RUNTIME_DIR; and test -n "$XDG_RUNTIME_DIR"
        set sock $XDG_RUNTIME_DIR/nagi-ssh.sock
      end
      exec ${tmux} -S $sock new-session -A -s ${sessionName}
    end
  '';
  attachTmuxBash = ''
    if test -n "$SSH_TTY" && test -z "$TMUX"; then
      ${systemctl} --user start nagi-ssh-tmux.service
      sock="''${XDG_RUNTIME_DIR:-/run/user/$(${coreutils}/bin/id -u)}/nagi-ssh.sock"
      exec ${tmux} -S "$sock" new-session -A -s ${sessionName}
    fi
  '';
  attachTmuxZsh = ''
    if [[ -n "$SSH_TTY" && -z "$TMUX" ]]; then
      ${systemctl} --user start nagi-ssh-tmux.service
      sock="''${XDG_RUNTIME_DIR:-/run/user/$(${coreutils}/bin/id -u)}/nagi-ssh.sock"
      exec ${tmux} -S "$sock" new-session -A -s ${sessionName}
    fi
  '';
in
{
  config = lib.mkIf enabled {
    home.packages = [ tmuxSsh ];

    programs = {
      tmux = {
        enable = true;
        prefix = "C-a";
        mouse = true;
        baseIndex = 1;
        escapeTime = 0;
        historyLimit = 100000;
        terminal = "tmux-256color";
        extraConfig = ''
          set -g extended-keys on
          set -g extended-keys-format csi-u
          set -g remain-on-exit on
          set -g destroy-unattached off
          set -g exit-unattached off
        '';
      };
      fish.interactiveShellInit = lib.mkAfter attachTmuxFish;
      bash.initExtra = lib.mkAfter attachTmuxBash;
      zsh.initContent = lib.mkIf zshEnabled (lib.mkAfter attachTmuxZsh);
    };

    systemd.user.services.nagi-ssh-tmux = {
      Unit.Description = "Persistent tmux server for SSH sessions";
      Service = {
        Type = "simple";
        # %t = $XDG_RUNTIME_DIR for the user manager. Pin the socket here so
        # the service never falls back to /tmp/tmux-<uid> after reboot.
        Environment = [ "TMUX_TMPDIR=%t" ];
        ExecStartPre = [
          "${coreutils}/bin/mkdir -p %t"
          # Drop stale sockets left by earlier socket-path layouts.
          "${coreutils}/bin/rm -f %t/nagi-ssh.sock %t/tmux-%U/nagi-ssh /tmp/tmux-%U/nagi-ssh"
        ];
        ExecStart = "${tmux} -S %t/nagi-ssh.sock -D";
        Restart = "on-failure";
        RestartSec = 1;
        KillMode = "mixed";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
