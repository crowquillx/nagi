{
  lib,
  config,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  primaryUser = get [ "users" "primary" ] "nagi";

  enabled = get [ "features" "ssh" "enable" ] true;
  openFirewall = get [ "features" "ssh" "openFirewall" ] true;
  port = get [ "features" "ssh" "port" ] 22;
  passwordAuthentication = get [ "features" "ssh" "passwordAuthentication" ] true;
  permitRootLogin = get [ "features" "ssh" "permitRootLogin" ] "prohibit-password";
  authorizedKeys = get [ "features" "ssh" "authorizedKeys" ] [ ];

  # Root login must never be widened to "yes"; keep it at least as
  # restrictive as the NixOS default ("prohibit-password").
  validRootLogin = [
    "prohibit-password"
    "without-password"
    "forced-commands-only"
    "no"
  ];
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = builtins.isBool enabled;
          message = "features.ssh.enable must be a boolean.";
        }
        {
          assertion = builtins.isBool openFirewall;
          message = "features.ssh.openFirewall must be a boolean.";
        }
        {
          assertion = builtins.isInt port && port > 0 && port <= 65535;
          message = "features.ssh.port must be an integer in 1..65535.";
        }
        {
          assertion = builtins.isBool passwordAuthentication;
          message = "features.ssh.passwordAuthentication must be a boolean.";
        }
        {
          assertion = builtins.elem permitRootLogin validRootLogin;
          message = "features.ssh.permitRootLogin must be one of: ${lib.concatStringsSep ", " validRootLogin} (never \"yes\").";
        }
        {
          assertion =
            builtins.isList authorizedKeys
            && builtins.all (k: builtins.isString k && k != "") authorizedKeys;
          message = "features.ssh.authorizedKeys must be a list of non-empty string public keys.";
        }
        {
          # Lockout guard: key-only mode requires at least one declared key,
          # otherwise disabling password auth would lock the user out.
          assertion = !(enabled && !passwordAuthentication && authorizedKeys == [ ]);
          message = "features.ssh.passwordAuthentication = false requires a non-empty features.ssh.authorizedKeys, otherwise the user is locked out of SSH.";
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

      users.users.${primaryUser}.openssh.authorizedKeys.keys = authorizedKeys;
    })
  ];
}
