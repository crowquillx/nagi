{
  host = {
    name = "tanlappy";
    isVm = false;
    timeZone = "America/Boise";
    locale = "en_US.UTF-8";
  };

  boot = {
    kernel = "zen";
    systemdBoot.enable = true;
    secureBoot = {
      enable = false;
      includeMicrosoftKeys = true;
      autoEnroll = false;
      pkiBundle = "/etc/secureboot";
    };
  };

  users = {
    primary = "tan";
    extraPackages = [
      "spotify"
      "mpv"
      "pywalfox-native"
      "sops"
      "qbittorrent"
    ];
    git = {
      name = "tan";
      email = "tancodes@proton.me";
    };
  };

  graphics = {
    profile = "amd";
  };

  desktop = {
    enable = true;
    compositor = "niri";
    extraCompositors = [ ];
    displayManager = "auto";
    sddm.wayland.enable = false;
    sddm.background = ../../wallpapers/1.png;
    browser = {
      default = "zen";
      zen.enable = true;
      helium.enable = true;
      mullvadBrowser.enable = false;
    };
    niri = {
      outputs = { };
      settings = { };
    };
    noctalia = import ./noctalia;
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
    startup.apps = [
      "spotify"
    ];
    startup.backend = "niri";
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
      enable = true;
      # Key-only SSH: password and keyboard-interactive auth are disabled.
      passwordAuthentication = false;
      authorizedKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCu4u2AElakm7r1HESc19BY3PsfQfkPb/mVoPu+Zw72d3W6qdO9HAT6OM5fxfV6yqQE0aH0ob9AHEI96+qbEx2TC35awUXXetOyMUckXtIqGPzazuBmA/WVoQjbNP2mHirhuUXUMm3sJz+e50riea2fvZ8mS7lTOXmfbnCilWNcKX+0gii1atPU0OMm0pghvGikrj1XcGFA+OcSGZdVSJPTDhfZZE236ch/9UxySFXO4Tk6gDXb46RElkiklGkfo9K0p14rf+XIeoHSvqYHiB0AECf/6t5pm/b5EGQqLaiKLM2b98abUX6N5bElc/Ok2sHw2Rar/8HuSJP0r91H1icqESa24ljl9SWc1rr6LwRx5OW2klwpRy9zdq+tfa3kp2yrAPZEYSFEHsCCzwdhNWq3suJaE/hlFyCJ8sVIiSeXsIjP1u75ek0xRoUdxGdh7w57X2Iud6PdxO/VaFkyZb/h9uYpabc40XChDvZnm2PS7hNre+sKsaLcfYNq4Q9C6Oc= tan@tandesk"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZbQQm+SOtRh2tAbJSa+kkObzIRV4xCkGfFB5eUMcnW tancodes@proton.me"
      ];
    };

  };

  security.sops = {
    enable = true;
    defaultSopsFile = ../../secrets/tanlappy.yaml;
    ageKeyFile = "/var/lib/sops-nix/key.txt";
    # Make the age key group-readable so sops CLI doesn't need sudo or
    # a /tmp copy. The user is added to this group at activation.
    administrativeGroup = "sops";
  };
}
