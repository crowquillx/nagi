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
        forceXwayland = false;
        equicord = {
          enable = true;
        };
      };
    };

    mullvad = {
      package = "gui";
      service = {
        enable = true;
        # Whonix-External is a local libvirt network; Mullvad otherwise blocks it.
        allowLan = true;
      };
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
        gemini.enable = true;
        pi.enable = true;
        ohMyPi.enable = true;
      };
      nixTools.enable = true;
    };
    mcp.nixos.enable = true;
    tailscale.enable = true;
    fileManager.thunar.enable = true;
    terminals = {
      alacritty.enable = true;
      foot.enable = true;
      kitty.enable = true;
    };
    videoEditing = {
      kdenlive.enable = true;
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
        "ru.linux_gaming.PortProton"
        {
          # Must match the bundle app-id exactly (uninstallUnmanaged).
          appId = "com.cakewallet.CakeWallet";
          bundle = {
            url = "https://github.com/cake-tech/cake_wallet/releases/download/v6.2.1/Cake_Wallet_v6.2.0_Linux.flatpak";
            hash = "sha256-GBybiogmaL+3mDxjRQuhqwtVEgx4UOqigwpWHR8iEq4=";
          };
        }
      ];
    };
    gaming = {
      enable = true;
      steam = {
        gamescopeSession.enable = false;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        millennium.enable = true;
      };
      cheatengine.enable = true;
    };
    virtualisation = {
      vmHost = {
        enable = true;
        spiceUSBRedirection.enable = true;
      };
      containers = {
        podman.enable = true;
        docker.enable = false;
      };
    };
    ai = {
      enable = false;
      comfyui = {
        enable = false;
      };
      ollama = {
        enable = false;
      };
      openWebui = {
        enable = false;
      };
    };
  };
}
