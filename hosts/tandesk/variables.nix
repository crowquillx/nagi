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
      "pinentry-bemenu"
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
    browser = {
      brave.passwordStore = "gnome-libsecret";
      mullvadBrowser.enable = true;
    };
    hyprland = {
      outputs = {
        "DP-3" = {
          mode = {
            width = 2560;
            height = 1440;
            refresh = 180.002;
          };
          scale = 1;
          workspaceBase = 0;
          transform = {
            rotation = 0;
            flipped = false;
          };
          position = {
            x = 2560;
            y = 1080;
          };
          variableRefreshRate = "on-demand";
          bitDepth = 10;
          colorManagement = "srgb";
          sdrBrightness = 1.0;
          sdrSaturation = 1.0;
          sdrMaxLuminance = 250;
          focusAtStartup = true;
        };
        "DP-2" = {
          mode = {
            width = 2560;
            height = 1440;
            refresh = 164.999;
          };
          scale = 1;
          workspaceBase = 100;
          transform = {
            rotation = 0;
            flipped = false;
          };
          position = {
            x = 0;
            y = 1080;
          };
        };
        "DP-1" = {
          mode = {
            width = 1920;
            height = 1080;
            refresh = 144.001;
          };
          scale = 1;
          workspaceBase = 200;
          transform = {
            rotation = 0;
            flipped = false;
          };
          position = {
            x = 2560;
            y = 0;
          };
        };
      };
    };
    session = {
      killProcessesOnLogout = true;
      polkit.enable = false;
    };
    hushmic.deviceId = "alsa_input.usb-Blue_Microphones_Yeti_X_2118SG005V78_888-000313110306-00.analog-stereo";
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
