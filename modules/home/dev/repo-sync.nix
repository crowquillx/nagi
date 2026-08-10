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
  repositories = get [ "features" "codingTools" "repoSync" "repositories" ] [ ];
  repositoryDirectory =
    if configuredDirectory == null then "${config.home.homeDirectory}/REPOS" else configuredDirectory;
  repositoryPaths = map (repository: repository.path) repositories;
  checkpointRepositoryPaths = map (repository: repository.path) (
    lib.filter (repository: repository.autoCheckpoint) repositories
  );
  encodedRepositoryPaths = lib.concatStringsSep ":" repositoryPaths;
  encodedCheckpointPaths = lib.concatStringsSep ":" checkpointRepositoryPaths;
  syncHost = get [ "host" "name" ] "unknown";
  sshKeyName = get [ "security" "sops" "sshKey" "name" ] "ssh_key";
  repoSync = pkgs.writeShellApplication {
    name = "nagi-repo-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.openssh
    ];
    text = builtins.readFile ../../../scripts/repo-sync;
  };
  repoCheckpoint = pkgs.writeShellApplication {
    name = "nagi-repo-checkpoint";
    runtimeInputs = [ repoSync ];
    text = ''
      if [[ -n "''${1-}" ]]; then
        checkpoint_target="$1"
        checkpoint_target_enabled=0
        configured_paths=( ${lib.escapeShellArgs checkpointRepositoryPaths} )
        for configured_path in "''${configured_paths[@]}"; do
          if [[ "$checkpoint_target" == "$configured_path" ]]; then
            checkpoint_target_enabled=1
            break
          fi
        done
        [[ "$checkpoint_target_enabled" -eq 1 ]] || exit 0
      fi

      export NAGI_REPO_SYNC_ROOT=${lib.escapeShellArg repositoryDirectory}
      export NAGI_REPO_SYNC_REMOTE_NAME=${lib.escapeShellArg remoteName}
      export NAGI_REPO_SYNC_REMOTE_HOST=${lib.escapeShellArg remoteHost}
      export NAGI_REPO_SYNC_MIRROR_DIR=${lib.escapeShellArg mirrorDirectory}
      export NAGI_REPO_SYNC_REPOSITORIES=${lib.escapeShellArg encodedRepositoryPaths}
      export NAGI_REPO_SYNC_CHECKPOINT_REPOSITORIES=${lib.escapeShellArg encodedCheckpointPaths}
      export NAGI_REPO_SYNC_HOST=${lib.escapeShellArg syncHost}
      exec nagi-repo-sync --checkpoint-only
    '';
  };
in
{
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = lib.all (repository: lib.hasPrefix "/" repository.path) repositories;
        message = "features.codingTools.repoSync.repositories paths must be absolute.";
      }
      {
        assertion = lib.all (repository: !(lib.hasInfix ":" repository.path)) repositories;
        message = "features.codingTools.repoSync.repositories paths cannot contain ':'.";
      }
    ];

    home.packages = [
      repoCheckpoint
      repoSync
    ];

    programs.ssh.settings.${remoteHost} = {
      HostName = remoteHost;
      User = remoteUser;
      IdentityFile = "~/.ssh/${sshKeyName}";
      IdentitiesOnly = true;
    };

    systemd.user = {
      services.nagi-repo-sync = {
        Unit = {
          Description = "Synchronize Git work and private checkpoints with ${remoteHost}";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${repoSync}/bin/nagi-repo-sync";
          Environment = [
            "NAGI_REPO_SYNC_ROOT=${repositoryDirectory}"
            "NAGI_REPO_SYNC_REMOTE_NAME=${remoteName}"
            "NAGI_REPO_SYNC_REMOTE_HOST=${remoteHost}"
            "NAGI_REPO_SYNC_MIRROR_DIR=${mirrorDirectory}"
            "NAGI_REPO_SYNC_REPOSITORIES=${encodedRepositoryPaths}"
            "NAGI_REPO_SYNC_CHECKPOINT_REPOSITORIES=${encodedCheckpointPaths}"
            "NAGI_REPO_SYNC_HOST=${syncHost}"
          ];
        };
      };

      timers.nagi-repo-sync = {
        Unit.Description = "Periodically synchronize Git work and private checkpoints";
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
