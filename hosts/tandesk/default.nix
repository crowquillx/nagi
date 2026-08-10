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

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
