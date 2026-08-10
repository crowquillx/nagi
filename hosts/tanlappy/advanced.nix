{
  features = {
    mullvad = {
      package = "cli";
      service.enable = false;
    };

    codingTools.aiCli.gemini.enable = false;

    tailscale = {
      exitNode = "tanime";
    };
    flatpak = {
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
      # thermald is Intel-oriented; power-profiles-daemon covers AMD on this host.
      thermald.enable = false;
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
