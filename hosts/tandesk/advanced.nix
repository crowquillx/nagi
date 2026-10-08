{
  desktop.umbriel.settings = {
    general.autostart = [
      "nagi-noctalia-shell"
      "spotify"
      "nagi-hushmic-tray"
      "sleep 5 && discord"
    ];

    environment.NVD_BACKEND = "direct";

    output = {
      DP-1 = {
        enabled = true;
        mode = "1920x1080@144.001";
        position = [
          2560
          0
        ];
        scale = 1;
      };
      DP-2 = {
        enabled = true;
        mode = "2560x1440@164.999";
        position = [
          0
          1080
        ];
        scale = 1;
      };
      DP-3 = {
        enabled = true;
        mode = "2560x1440@180.002";
        position = [
          2560
          1080
        ];
        scale = 1;
        vrr = "fullscreen";
        hdr = "auto";
        sdr_white = 250;
      };
      # LG C2 TV over HDMI 2.1: optional gaming display, disabled by default.
      # Connector verified via /sys/class/drm/card1-HDMI-A-1 (only HDMI port;
      # currently disconnected while the TV is off) and `umbriel outputs`.
      # Runtime enable is temporary (`output-toggle`); reboot returns to disabled.
      "HDMI-A-1" = {
        enabled = false;
        mode = "3840x2160@120";
        position = [
          5120
          0
        ];
        scale = 1;
        vrr = "fullscreen";
        hdr = "auto";
      };
    };

    # Dedicated gaming workspace bound to the TV. While HDMI-A-1 is disabled,
    # Umbriel parks GAME plus its windows on another enabled output and
    # returns them when the TV is re-enabled; new game windows fall back to
    # the preferred (normally DP-3) output in that state.
    workspace = [
      {
        name = "GAME";
        output = "HDMI-A-1";
      }
    ];

    keybinds = {
      "Mod+G" = "output-toggle:HDMI-A-1";
      "Mod+Ctrl+Left" = "output-focus-left";
      "Mod+Ctrl+Right" = "output-focus-right";
      "Mod+Ctrl+H" = "output-focus-left";
      "Mod+Ctrl+J" = "output-focus-down";
      "Mod+Ctrl+K" = "output-focus-up";
      "Mod+Ctrl+L" = "output-focus-right";
      "Mod+Shift+Ctrl+Left" = "column-move-to-output-left";
      "Mod+Shift+Ctrl+Down" = "column-move-to-output-down";
      "Mod+Shift+Ctrl+Up" = "column-move-to-output-up";
      "Mod+Shift+Ctrl+Right" = "column-move-to-output-right";
      "Mod+Shift+Ctrl+H" = "column-move-to-output-left";
      "Mod+Shift+Ctrl+J" = "column-move-to-output-down";
      "Mod+Shift+Ctrl+K" = "column-move-to-output-up";
      "Mod+Shift+Ctrl+L" = "column-move-to-output-right";
    };

    window_rule = [
      {
        match.app_id = "^awakened-poe-trade$";
        default_output = "DP-3";
        default_floating = true;
        blur = false;
      }
      {
        match.app_id = "^(steam_app_238960|steam_app_2694490)$";
        default_output = "HDMI-A-1";
        default_workspace = "GAME";
        default_fullscreen = true;
        hdr = "auto";
      }
      {
        match.app_id = "^steam_app_[0-9]+$";
        default_output = "HDMI-A-1";
        default_workspace = "GAME";
        default_fullscreen = true;
        hdr = "auto";
      }
      {
        match.app_id = "^(steam_proton|.*[.]exe)$";
        default_output = "HDMI-A-1";
        default_workspace = "GAME";
        default_fullscreen = true;
        blur = false;
      }
      # VRR/HDR follow for any game content, including fallback to DP-3 while
      # the TV is disabled.
      {
        match.content_type = "game";
        vrr = "fullscreen";
        hdr = "auto";
      }
      {
        match.app_id = "^(discord|com[.]discordapp[.]Discord|equibop)$";
        default_output = "DP-1";
        default_maximize = true;
      }
      {
        match.app_id = "^electron$";
        match.title = "^.*[Dd][Ii][Ss][Cc][Oo][Rr][Dd].*$";
        default_output = "DP-1";
        default_maximize = true;
      }
      {
        match.app_id = "^spotify$";
        default_output = "DP-2";
        default_maximize = true;
      }
    ];
  };

  features = {
    chat.discord = {
      forceXwayland = false;
      mouseMute = {
        enable = true;
        device = "/dev/input/by-id/usb-Razer_Razer_Viper_V3_Pro-event-mouse";
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

    tailscale.disableUpstreamLogging = true;

    codingTools.aiCli.gemini.enable = true;
    mcp.computerUseLinux.enable = true;
    videoEditing.kdenlive.enable = true;
    blender.enable = true;
    razer = {
      openrazer = {
        enable = true;
        users = [ "tan" ];
      };
      inputRemapper.enable = true;
    };
    flatpak = {
      packages = [
        "org.upscayl.Upscayl"
        "ru.linux_gaming.PortProton"
        "org.freedesktop.Platform.VulkanLayer.gamescope//25.08"
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
        gamescopeSession.enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        millennium.enable = true;
      };
      cheatengine.enable = true;
      pcsx2.enable = true;
      gamemode.enable = true;
      godot.enable = true;
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
