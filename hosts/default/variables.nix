{
  host = {
    name = "default";
    isVm = true;
    timeZone = "America/Chicago";
    locale = "en_US.UTF-8";
    stateVersion = {
      nixos = "25.05";
      home = "25.05";
    };
  };

  boot.systemdBoot.enable = true;
  boot.secureBoot = {
    enable = false;
    # Keep Microsoft UEFI CA/3rd-party keys available for dual-boot and vendor tooling.
    includeMicrosoftKeys = true;
    # Set true after reading docs/SECURE_BOOT.md and confirming firmware setup steps.
    autoEnroll = false;
    # Lanzaboote/sbctl conventional PKI location.
    pkiBundle = "/var/lib/sbctl";
  };

  users = {
    primary = "nagi";
    flakeDirectory = null;
    extraPackages = [ ];
    git = {
      name = null;
      email = null;
    };
  };

  graphics = {
    profile = "vm";
  };

  desktop = {
    enable = true;
    compositor = "hyprland";
    extraCompositors = [ ];
    displayManager = "auto";
    browser = {
      default = "mullvadBrowser";
      zen.enable = false;
      helium.enable = false;
      mullvadBrowser.enable = true;
    };
    hyprland = {
      outputs = { };
      settings = { };
    };
    sessionShell = "noctalia";
    noctalia = {
      command = "nagi-noctalia-shell";
      settings = { };
    };
    session = {
      enable = true;
      polkit.enable = true;
      keyring.enable = true;
      lock = {
        enable = true;
        idleSeconds = 300;
        beforeSleep = true;
        onLidClose = true;
      };
    };
    shellStartupCommand = null;
  };

  features = {
    stylix = {
      enable = true;
      variant = "moon";
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

    ssh = {
      # Keep SSH off in the copyable template until authorizedKeys are set.
      # Enabling password auth with an empty key list would expose password SSH.
      enable = false;
      passwordAuthentication = false;
      authorizedKeys = [ ];
    };

  };

  security.sops = {
    enable = false;
    defaultSopsFile = null;
    ageKeyFile = "/var/lib/sops-nix/key.txt";
  };
}
