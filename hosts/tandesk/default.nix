{ lib, ... }: {
  imports = [
    ../common/default.nix
    ../profiles/pango.nix
    ./hardware-configuration.nix
  ];

  boot = {
    initrd = {
      systemd.enable = true;
      # Keep FIDO2 and passphrase recovery available after TPM enrollment.
      luks.devices."luks-840bc2c4-3551-4cd7-b379-e0e70db6b623".crypttabExtraOpts = [
        "tpm2-device=auto"
        "fido2-device=auto"
        "token-timeout=5s"
      ];
    };
    lanzaboote.measuredBoot = {
      enable = true;
      pcrs = [ 0 4 7 ];
      # This firmware omits the EFI Application action event. Requiring it
      # makes pcrlock drop PCR 4 even though its recorded measurements match.
      upstreamStaticMeasurements = lib.mkForce [
        "500-separator.pcrlock.d/300-0x00000000.pcrlock"
        "400-secureboot-separator.pcrlock.d/300-0x00000000.pcrlock"
      ];
    };
    supportedFilesystems."ntfs-3g" = true;
  };

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
