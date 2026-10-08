{
  lib,
  vars ? { },
  ...
}:
let
  enabled = lib.attrByPath [ "features" "virtualisation" "macosBuilder" "enable" ] false vars;
  sshPort = lib.attrByPath [ "features" "virtualisation" "macosBuilder" "sshPort" ] 2222 vars;
  guestUser = lib.attrByPath [ "users" "primary" ] "tan" vars;
in
{
  config = lib.mkIf enabled {
    programs.ssh.settings.macbuild = {
      HostName = "127.0.0.1";
      Port = sshPort;
      User = guestUser;
      HostKeyAlias = "macbuild";
      IdentityFile = "~/.ssh/macbuild_ed25519";
      IdentitiesOnly = true;
      ForwardAgent = false;
    };
  };
}
