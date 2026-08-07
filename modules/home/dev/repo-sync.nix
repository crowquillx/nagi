{
  config,
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  enabled = get [ "features" "codingTools" "repoSync" "enable" ] false;
  remoteHost = get [ "features" "codingTools" "repoSync" "remoteHost" ] "codebox";
  remoteUser = get [ "features" "codingTools" "repoSync" "remoteUser" ] "tan";
  remoteName = get [ "features" "codingTools" "repoSync" "remoteName" ] "codebox";
  mirrorDirectory = get [ "features" "codingTools" "repoSync" "mirrorDirectory" ] "git-mirrors";
  interval = get [ "features" "codingTools" "repoSync" "interval" ] "2m";
  configuredDirectory = get [ "features" "codingTools" "repoSync" "directory" ] null;
  repositoryDirectory =
    if configuredDirectory == null
    then "${config.home.homeDirectory}/REPOS"
    else configuredDirectory;
  sshKeyName = get [ "security" "sops" "sshKey" "name" ] "ssh_key";
  repoSync = pkgs.writeShellApplication {
    name = "nagi-repo-sync";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
    ];
    text = builtins.readFile ../../../scripts/repo-sync;
  };
in
{
  config = lib.mkIf enabled {
    home.packages = [ repoSync ];

    programs.ssh.settings.${remoteHost} = {
      HostName = remoteHost;
      User = remoteUser;
      IdentityFile = "~/.ssh/${sshKeyName}";
      IdentitiesOnly = true;
    };

    systemd.user = {
      services.nagi-repo-sync = {
        Unit = {
          Description = "Synchronize committed Git work with ${remoteHost}";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
          ConditionPathIsDirectory = repositoryDirectory;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${repoSync}/bin/nagi-repo-sync";
          Environment = [
            "NAGI_REPO_SYNC_ROOT=${repositoryDirectory}"
            "NAGI_REPO_SYNC_REMOTE_NAME=${remoteName}"
            "NAGI_REPO_SYNC_REMOTE_HOST=${remoteHost}"
            "NAGI_REPO_SYNC_MIRROR_DIR=${mirrorDirectory}"
          ];
        };
      };

      timers.nagi-repo-sync = {
        Unit.Description = "Periodically synchronize committed Git work";
        Timer = {
          OnBootSec = "2m";
          OnUnitActiveSec = interval;
          Persistent = true;
          Unit = "nagi-repo-sync.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
