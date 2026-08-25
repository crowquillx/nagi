{
  host = {
    name = "tandesk";
    isVm = false;
  };

  storage.mounts = [
    {
      device = "/dev/disk/by-uuid/a93a28c3-8538-45f9-9031-1d740a0993f1";
      mountPoint = "/mnt/games";
      fsType = "ext4";
      options = [
        "defaults"
        "nofail"
      ];
    }
    {
      device = "/dev/disk/by-uuid/59ad586e-b4ed-4e44-bda1-2412e5e5b9e3";
      mountPoint = "/mnt/games1";
      fsType = "ext4";
      options = [
        "defaults"
        "nofail"
      ];
    }
  ];

  boot.secureBoot.enable = true;

  users = {
    primary = "tan";
    extraPackages = [
      "spotify"
      "mpv"
      "pywalfox-native"
      "sops"
      "age"
      "gnupg"
      "yubikey-manager"
      "pinentry-qt"
      "qbittorrent"
      "proton-vpn"
      "brave"
      "mkvtoolnix"
      "osu-lazer-bin"
      "hushmic"
      "vortex"
      "ntfs3g"
    ];
  };

  graphics = {
    profile = "nvidia";
    enable32Bit = true;
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = true;
      nvidiaSettings = true;
      useLatestDriver = true;
    };
  };

  desktop = {
    compositor = "plasma";

    # tan-common defaults are Hyprland/Noctalia-flavored; override them for
    # Plasma. The lock command goes through logind, which KWin handles.
    noctalia.enable = false;
    session.lock.command = "loginctl lock-session";
    startup.backend = "systemd";

    browser = {
      brave.passwordStore = "gnome-libsecret";
      mullvadBrowser.enable = true;
    };
    session = {
      killProcessesOnLogout = true;
      polkit.enable = false;
    };
    hushmic.deviceId = "alsa_input.usb-Blue_Microphones_Yeti_X_2118SG005V78_888-000313110306-00.analog-stereo";
    hdrGame = {
      enable = true;
      monitor = {
        # AOC Q27G3XMN Mini-LED; UUID is the stable KScreen identity,
        # model+serial verify against live EDID, DP-3 is last resort only.
        uuid = "f113902c-3db2-4cde-bb99-8045f09f995b";
        model = "Q27G3XMN";
        serial = "1APR3JA002499";
        fallbackConnector = "DP-3";
      };
      notifications.enable = true;
    };
    startup.apps = [
      "spotify"
      "nagi-hushmic-tray"
    ];
  };

  features = {
    ssh = {
      autoTmux = {
        enable = true;
        sessionName = "ssh";
      };
    };

    swap = {
      zram = {
        enable = true;
        memoryPercent = 25;
      };
      disk = {
        enable = true;
        path = "/var/lib/swapfile";
        sizeMiB = 4096;
      };
      swappiness = 10;
    };

  };

  security.sops = {
    defaultSopsFile = ../../secrets/tandesk.yaml;
    # sops-nix is mutually exclusive between gnupgHome and ageKeyFile at
    # runtime, so we use the age key file for unattended boot. The Yubikey
    # PGP key is still a recipient in the sops file (added via
    # `sops updatekeys`); gpg-agent uses it when you run `sops` manually.
  };

  security.yubikey = {
    enable = true;
  };

  home.security.yubikey = {
    # Path to the ASCII-armored PGP public key. The HM activation script
    # imports it into ~/.gnupg so gpg-agent can use the Yubikey for sops
    # CLI and any other GPG operations.
    pgpPublicKey = ../../secrets/yubikey-pgp-pub.asc;
  };
}
