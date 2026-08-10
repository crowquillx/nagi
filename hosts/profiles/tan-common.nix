{
  host = {
    timeZone = "America/Boise";
    locale = "en_US.UTF-8";
    stateVersion = {
      nixos = "25.05";
      home = "25.05";
    };
  };

  boot = {
    kernel = "zen";
    systemdBoot.enable = true;
    secureBoot = {
      includeMicrosoftKeys = true;
      autoEnroll = false;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  users = {
    git = {
      name = "tan";
      email = "tancodes@proton.me";
    };
  };

  desktop = {
    enable = true;
    compositor = "hyprland";
    extraCompositors = [ ];
    displayManager = "auto";
    sddm = {
      wayland.enable = false;
      background = ../../wallpapers/1.png;
    };
    browser = {
      default = "zen";
      zen.enable = true;
      helium.enable = true;
    };
    noctalia = {
      enable = true;
      command = "nagi-noctalia-shell";
      assistantPanel.secrets = { };
    };
    session = {
      enable = true;
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
    startup.backend = "hyprland";
  };

  features = {
    stylix = {
      enable = true;
      variant = "main";
    };
    shell = {
      fish.enable = false;
      zsh.enable = true;
      starship.enable = true;
    };
    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep-since 4d --keep 3";
      };
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
      passwordAuthentication = false;
      authorizedKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCu4u2AElakm7r1HESc19BY3PsfQfkPb/mVoPu+Zw72d3W6qdO9HAT6OM5fxfV6yqQE0aH0ob9AHEI96+qbEx2TC35awUXXetOyMUckXtIqGPzazuBmA/WVoQjbNP2mHirhuUXUMm3sJz+e50riea2fvZ8mS7lTOXmfbnCilWNcKX+0gii1atPU0OMm0pghvGikrj1XcGFA+OcSGZdVSJPTDhfZZE236ch/9UxySFXO4Tk6gDXb46RElkiklGkfo9K0p14rf+XIeoHSvqYHiB0AECf/6t5pm/b5EGQqLaiKLM2b98abUX6N5bElc/Ok2sHw2Rar/8HuSJP0r91H1icqESa24ljl9SWc1rr6LwRx5OW2klwpRy9zdq+tfa3kp2yrAPZEYSFEHsCCzwdhNWq3suJaE/hlFyCJ8sVIiSeXsIjP1u75ek0xRoUdxGdh7w57X2Iud6PdxO/VaFkyZb/h9uYpabc40XChDvZnm2PS7hNre+sKsaLcfYNq4Q9C6Oc= tan@tandesk"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZbQQm+SOtRh2tAbJSa+kkObzIRV4xCkGfFB5eUMcnW tancodes@proton.me"
      ];
    };
    localsend = {
      package.enable = true;
      openFirewall = true;
    };
    chat = {
      client = "discord";
      startup.enable = true;
      discord.equicord.enable = true;
    };
    codingTools = {
      enable = true;
      editors = {
        enable = true;
        t3code.enable = true;
        cursor.enable = true;
        zed.enable = true;
      };
      aiCli = {
        enable = true;
        codex.enable = true;
        opencode.enable = true;
        opencode2.enable = true;
        pi.enable = true;
        ohMyPi.enable = true;
        primeAgent.enable = true;
      };
      nixTools.enable = true;
    };
    mcp.nixos.enable = true;
    tailscale.enable = true;
    fileManager.thunar.enable = true;
    terminals = {
      default = "ghostty";
      alacritty.enable = true;
      foot.enable = true;
      ghostty.enable = true;
      kitty.enable = true;
    };
    videoEditing.davinciResolve = {
      enable = false;
      edition = "free";
    };
    theme = {
      gtk = {
        enable = true;
        iconTheme = {
          name = "rose-pine";
          package = "rose-pine-icon-theme";
        };
      };
      qt.enable = true;
    };
    zoxide.enable = true;
    bluetooth.enable = true;
    networking.networkmanager.enable = true;
    portals.enable = true;
    services = {
      fstrim.enable = true;
      resolved.enable = true;
      powerProfilesDaemon.enable = true;
    };
    printing.enable = false;
    flatpak.enable = true;
  };

  security.sops = {
    enable = true;
    ageKeyFile = "/var/lib/sops-nix/key.txt";
    administrativeGroup = "sops";
    sshKey = {
      enable = true;
      name = "ssh_key";
      pubName = "ssh_key_pub";
    };
    signingKey = {
      enable = true;
      name = "ssh_signing_key";
      pubName = "ssh_signing_key_pub";
    };
  };
}
