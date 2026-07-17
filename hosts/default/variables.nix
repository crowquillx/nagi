{
  host = {
    name = "default";
    isVm = true;
    timeZone = "America/Chicago";
    locale = "en_US.UTF-8";
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
    compositor = "niri";
    extraCompositors = [];
    displayManager = "auto";
    browser = {
      default = "mullvadBrowser";
      zen.enable = false;
      helium.enable = false;
      mullvadBrowser.enable = true;
    };
    niri = {
      # Populate output names with `niri msg outputs`.
      outputs = {};
      settings = {};
    };
    noctalia = {
      enable = true;
      command = "nagi-noctalia-shell";
      settings = {};
    };
    session = {
      enable = true;
      polkit.enable = true;
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
