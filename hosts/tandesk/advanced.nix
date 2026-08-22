{
  features = {
    chat.discord.forceXwayland = false;

    mullvad = {
      package = "gui";
      service = {
        enable = true;
        # Whonix-External is a local libvirt network; Mullvad otherwise blocks it.
        allowLan = true;
      };
    };

    codingTools.aiCli.gemini.enable = true;
    videoEditing.kdenlive.enable = true;
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
      gamemode.enable = true;
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
