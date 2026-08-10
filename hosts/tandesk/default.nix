{ ... }: {
  imports = [
    ../common/default.nix
    ../profiles/pango.nix
    ./hardware-configuration.nix
  ];

  services.logind.settings = {
    Login = {
      HandlePowerKey = "poweroff";
      HandleSuspendKey = "ignore";
      HandleHibernateKey = "ignore";
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
  };

  services.teamviewer.enable = true;

  programs.ssh.knownHosts.tanlappy.publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8xhsg67hSFq4ouV7yWw04UOyYo/fVIHuHL+d1ABvwq";

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
