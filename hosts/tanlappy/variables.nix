{
  host = {
    name = "tanlappy";
    isVm = false;
  };

  boot.secureBoot.enable = false;

  users = {
    primary = "tan";
    extraPackages = [
      "spotify"
      "mpv"
      "pywalfox-native"
      "sops"
      "qbittorrent"
    ];
  };

  graphics = {
    profile = "amd";
  };

  desktop = {
    compositor = "niri";
    browser = {
      mullvadBrowser.enable = false;
    };
    session = {
      # Noctalia owns the authentication agent in Niri sessions.
      polkit.enable = false;
    };
    startup.apps = [
      "spotify"
    ];
    startup.backend = "niri";
  };

  features = {
    swap = {
      # Single deliberate design for this AMD laptop: compressed zram only.
      # Disk swapfile is redundant alongside zram and was paired with a broken
      # undeclared LUKS swap mapper in hardware-configuration.nix.
      zram = {
        enable = true;
        memoryPercent = 25;
      };
      disk = {
        enable = false;
        path = "/var/lib/swapfile";
        sizeMiB = 4096;
      };
      swappiness = 10;
    };

  };

  security.sops = {
    defaultSopsFile = ../../secrets/tanlappy.yaml;
  };
}
