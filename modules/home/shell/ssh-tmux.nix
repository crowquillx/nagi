{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  enabled = get [ "features" "ssh" "autoTmux" "enable" ] false;
  sessionName = get [ "features" "ssh" "autoTmux" "sessionName" ] "ssh";
  socketName = "nagi-ssh";
  tmux = "${pkgs.tmux}/bin/tmux";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  attachTmuxFish = ''
    if set -q SSH_TTY; and not set -q TMUX
      ${systemctl} --user start nagi-ssh-tmux.service
      exec ${tmux} -L ${socketName} new-session -A -s ${sessionName}
    end
  '';
  attachTmuxBash = ''
    if test -n "$SSH_TTY" && test -z "$TMUX"; then
      ${systemctl} --user start nagi-ssh-tmux.service
      exec ${tmux} -L ${socketName} new-session -A -s ${sessionName}
    fi
  '';
in
{
  config = lib.mkIf enabled {
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
        '';
      };
      fish = {
        interactiveShellInit = lib.mkAfter attachTmuxFish;
        shellAliases.tmux-ssh = "${tmux} -L ${socketName}";
      };
      bash = {
        initExtra = lib.mkAfter attachTmuxBash;
        shellAliases.tmux-ssh = "${tmux} -L ${socketName}";
      };
    };

    systemd.user.services.nagi-ssh-tmux = {
      Unit.Description = "Persistent tmux server for SSH sessions";
      Service = {
        ExecStart = "${tmux} -L ${socketName} -D";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
