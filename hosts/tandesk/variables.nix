{
  host = {
    name = "tandesk";
    isVm = false;
    timeZone = "America/Boise";
    locale = "en_US.UTF-8";
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
  ];

  boot = {
    kernel = "zen";
    systemdBoot.enable = true;
    secureBoot = {
      enable = true;
      # Keep Microsoft UEFI CA/3rd-party keys available for dual-boot and vendor tooling.
      includeMicrosoftKeys = true;
      # Set true after reading docs/SECURE_BOOT.md and confirming firmware setup steps.
      autoEnroll = false;
      # Default sbctl/Lanzaboote PKI location.
      pkiBundle = "/var/lib/sbctl";
    };
  };

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
    ];
    git = {
      name = "tan";
      email = "tancodes@proton.me";
    };
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
    enable = true;
    compositor = "niri";
    extraCompositors = [ "plasma" ];
    displayManager = "auto";
    sddm.wayland.enable = false;
    sddm.background = ../../wallpapers/1.png;
    browser = {
      default = "zen";
      zen.enable = true;
      helium.enable = true;
      mullvadBrowser.enable = true;
    };
    niri = {
      outputs = {
        "DP-3" = {
          mode = {
            width = 2560;
            height = 1440;
            refresh = 180.002;
          };
          scale = 1;
          transform = {
            rotation = 0;
            flipped = false;
          };
          position = {
            x = 2560;
            y = 1080;
          };
          variableRefreshRate = "on-demand";
          focusAtStartup = true;
        };
        "DP-2" = {
          mode = {
            width = 2560;
            height = 1440;
            refresh = 164.999;
          };
          scale = 1;
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
      settings = { };
    };
    noctalia = import ./noctalia;
    session = {
      enable = true;
      polkit.enable = false;
      keyring.enable = true;
      lock = {
        enable = true;
        command = "nagi-noctalia-shell msg session lock";
        idleSeconds = 300;
        beforeSleep = true;
        onLidClose = true;
      };
    };
    shellStartupCommand = null;
    startup.apps = [
      "spotify"
      "hushmic"
    ];
    startup.backend = "niri";
  };

  features = {
    stylix = {
      enable = true;
      variant = "moon";
    };

    ssh = {
      enable = true;
      # Key-only SSH: password and keyboard-interactive auth are disabled.
      # Both keys below are authorized for user `tan`.
      passwordAuthentication = false;
      authorizedKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCu4u2AElakm7r1HESc19BY3PsfQfkPb/mVoPu+Zw72d3W6qdO9HAT6OM5fxfV6yqQE0aH0ob9AHEI96+qbEx2TC35awUXXetOyMUckXtIqGPzazuBmA/WVoQjbNP2mHirhuUXUMm3sJz+e50riea2fvZ8mS7lTOXmfbnCilWNcKX+0gii1atPU0OMm0pghvGikrj1XcGFA+OcSGZdVSJPTDhfZZE236ch/9UxySFXO4Tk6gDXb46RElkiklGkfo9K0p14rf+XIeoHSvqYHiB0AECf/6t5pm/b5EGQqLaiKLM2b98abUX6N5bElc/Ok2sHw2Rar/8HuSJP0r91H1icqESa24ljl9SWc1rr6LwRx5OW2klwpRy9zdq+tfa3kp2yrAPZEYSFEHsCCzwdhNWq3suJaE/hlFyCJ8sVIiSeXsIjP1u75ek0xRoUdxGdh7w57X2Iud6PdxO/VaFkyZb/h9uYpabc40XChDvZnm2PS7hNre+sKsaLcfYNq4Q9C6Oc= tan@tandesk"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZbQQm+SOtRh2tAbJSa+kkObzIRV4xCkGfFB5eUMcnW tancodes@proton.me"
      ];
    };

    shell = {
      fish.enable = true;
      starship.enable = true;
    };

    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep-since 4d --keep 3";
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

    nixMaintenance = {
      gc.enable = false;
      optimise = {
        enable = true;
        dates = "weekly";
      };
    };

    audio.enable = true;
  };

  security.sops = {
    enable = true;
    defaultSopsFile = ../../secrets/tandesk.yaml;
    ageKeyFile = "/var/lib/sops-nix/key.txt";
    # Make the age key group-readable so sops CLI doesn't need sudo or
    # a /tmp copy. The user is added to this group at activation.
    administrativeGroup = "sops";
    # sops-nix is mutually exclusive between gnupgHome and ageKeyFile at
    # runtime, so we use the age key file for unattended boot. The Yubikey
    # PGP key is still a recipient in the sops file (added via
    # `sops updatekeys`); gpg-agent uses it when you run `sops` manually.
    sshKey = {
      enable = true;
      name = "ssh_key";
      pubName = "ssh_key_pub";
    };
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
