{
  lib,
  config,
  ...
}:
let
  v = config.nagi.variables;
  primaryUser = v.users.primary;

  ssh = v.features.ssh;
  repoSync = v.features.codingTools.repoSync;
  inherit (ssh)
    authorizedKeys
    openFirewall
    passwordAuthentication
    permitRootLogin
    port
    ;
  enabled = ssh.enable;
  autoTmuxEnabled = ssh.autoTmux.enable;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          # types.port is u16 (0..65535); reject 0 so SSH always binds a real port.
          assertion = !enabled || port > 0;
          message = "features.ssh.port must be an integer in 1..65535.";
        }
        {
          # Lockout guard: key-only mode requires at least one declared key,
          # otherwise disabling password auth would lock the user out.
          assertion = !(enabled && !passwordAuthentication && authorizedKeys == [ ]);
          message = "features.ssh.passwordAuthentication = false requires a non-empty features.ssh.authorizedKeys, otherwise the user is locked out of SSH.";
        }
        {
          assertion = !autoTmuxEnabled || enabled;
          message = "features.ssh.autoTmux.enable requires features.ssh.enable.";
        }
      ];
    }
    (lib.mkIf enabled {
      services.openssh = {
        enable = true;
        inherit openFirewall;
        ports = [ port ];
        settings = {
          # openssh settings options are capitalized; map from our
          # lowercase variables explicitly.
          PasswordAuthentication = passwordAuthentication;
          PermitRootLogin = permitRootLogin;
          # Tie kbd-interactive to the password policy so key-only mode
          # cannot be bypassed via keyboard-interactive auth.
          KbdInteractiveAuthentication = passwordAuthentication;
        };
      };

      users.users.${primaryUser} = {
        linger = lib.mkIf autoTmuxEnabled true;
        openssh.authorizedKeys.keys = authorizedKeys;
      };
    })
    (lib.mkIf (repoSync.enable && repoSync.remotePublicKey != null) {
      programs.ssh.knownHosts.${repoSync.remoteHost}.publicKey = repoSync.remotePublicKey;
    })
  ];
}
