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
      ${tmux} -L ${socketName} has-session -t ${sessionName} 2>/dev/null; or ${tmux} -L ${socketName} new-session -d -s ${sessionName}
      exec ${tmux} -L ${socketName} attach-session -t ${sessionName}
    end
  '';
  attachTmuxBash = ''
    if test -n "$SSH_TTY" && test -z "$TMUX"; then
      ${systemctl} --user start nagi-ssh-tmux.service
      ${tmux} -L ${socketName} has-session -t ${sessionName} 2>/dev/null || ${tmux} -L ${socketName} new-session -d -s ${sessionName}
      exec ${tmux} -L ${socketName} attach-session -t ${sessionName}
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
      };
      fish.interactiveShellInit = lib.mkAfter attachTmuxFish;
      bash.initExtra = lib.mkAfter attachTmuxBash;
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
