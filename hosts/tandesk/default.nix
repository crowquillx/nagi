{ ... }: {
  imports = [
    ../common/default.nix
    ../profiles/pango.nix
    ./hardware-configuration.nix
  ];

  # Use an enrolled FIDO2 token first, then fall back to the existing LUKS
  # passphrase when no suitable token appears.
  boot.initrd.luks.devices."luks-840bc2c4-3551-4cd7-b379-e0e70db6b623".crypttabExtraOpts = [
    "fido2-device=auto"
    "token-timeout=5s"
  ];
  boot.supportedFilesystems."ntfs-3g" = true;

  services = {
    logind.settings = {
      Login = {
        HandlePowerKey = "poweroff";
        HandleSuspendKey = "ignore";
        HandleHibernateKey = "ignore";
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
      };
    };

    teamviewer.enable = true;
    udisks2.settings."mount_options.conf".defaults.ntfs_drivers = [
      "ntfs"
      "ntfs3"
    ];
  };

  programs.ssh.knownHosts.tanlappy.publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8xhsg67hSFq4ouV7yWw04UOyYo/fVIHuHL+d1ABvwq";

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
