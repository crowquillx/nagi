{
  features = {
    localsend = {
      package.enable = true;
      openFirewall = true;
    };

    chat = {
      client = "discord";
      startup.enable = true;
      discord = {
        forceXwayland = true;
        equicord = {
          enable = true;
          startupDelaySeconds = 4;
        };
      };
    };

    mullvad = {
      package = "cli";
      service.enable = false;
    };

    codingTools = {
      enable = true;
      editors = {
        enable = true;
        vscode.enable = true;
        antigravity.enable = false;
        t3code.enable = true;
        cursor.enable = true;
        zed.enable = true;
      };
      aiCli = {
        enable = true;
        codex.enable = true;
        opencode.enable = true;
        gemini.enable = false;
        pi.enable = true;
        ohMyPi.enable = true;
      };
      nixTools.enable = true;
    };
    mcp.nixos.enable = true;
    fileManager.thunar.enable = true;
    terminals = {
      alacritty.enable = true;
      foot.enable = true;
      kitty.enable = true;
    };
    videoEditing = {
      kdenlive.enable = false;
      davinciResolve = {
        enable = false;
        edition = "free";
      };
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

    tailscale = {
      enable = true;
      exitNode = "tanime";
    };
    portals.enable = true;
    services = {
      fstrim.enable = true;
      resolved.enable = true;
      powerProfilesDaemon.enable = true;
    };
    printing.enable = false;
    flatpak = {
      enable = true;
      packages = [
        "org.upscayl.Upscayl"
      ];
    };
    gaming = {
      enable = false;
      # gaming.enable is false, so these toggles are inert regardless.
      # Set to false to reflect honest intent (no Steam ports on this host).
      steam = {
        gamescopeSession.enable = false;
        remotePlay.openFirewall = false;
        dedicatedServer.openFirewall = false;
        localNetworkGameTransfers.openFirewall = false;
      };
    };
    virtualisation = {
      vmHost = {
        enable = false;
        spiceUSBRedirection.enable = true;
      };
      containers = {
        podman.enable = false;
        docker.enable = false;
      };
    };

    laptop = {
      enable = true;

      upower.enable = true;
      tlp.enable = false;
      thermald.enable = true;
      powertop.enable = false;
      fwupd.enable = true;

      logind = {
        lidSwitch = "suspend";
        lidSwitchExternalPower = "ignore";
        lidSwitchDocked = "ignore";
      };
    };
  };
}
