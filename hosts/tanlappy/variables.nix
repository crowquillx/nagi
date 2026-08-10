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
    browser = {
      mullvadBrowser.enable = false;
    };
    session = {
      polkit.enable = true;
    };
    startup.apps = [
      "spotify"
    ];
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
