{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  primaryUser = v.users.primary;
  fishEnabled = v.features.shell.fish.enable;
  zshEnabled = v.features.shell.zsh.enable;
  maintenance = v.features.nixMaintenance;
  binaryCaches = import ./binary-caches.nix;
in
{
  assertions = [
    {
      assertion = !(fishEnabled && zshEnabled);
      message = "features.shell.fish.enable and features.shell.zsh.enable cannot both be true.";
    }
  ];

  nix = {
    settings = binaryCaches // {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = false;
      trusted-users = [
        primaryUser
      ];
    };
    gc = {
      automatic = maintenance.gc.enable;
      inherit (maintenance.gc) dates options;
    };
    optimise = {
      automatic = maintenance.optimise.enable;
      inherit (maintenance.optimise) dates;
    };
  };

  time.timeZone = v.host.timeZone;
  i18n.defaultLocale = v.host.locale;

  boot = {
    loader = {
      systemd-boot = {
        enable = lib.mkDefault v.boot.systemdBoot.enable;
        configurationLimit = lib.mkDefault 7;
        consoleMode = lib.mkDefault "max";
      };
      efi.canTouchEfiVariables = lib.mkDefault true;
    };

    kernelPackages =
      let
        kernel = v.boot.kernel;
      in
      if kernel == "zen" then
        pkgs.linuxPackages_zen
      else if kernel == "latest" then
        pkgs.linuxPackages_latest
      else
        pkgs.linuxPackages;
  };

  networking.networkmanager.enable = lib.mkDefault false;

  security = {
    rtkit.enable = true;
    polkit.enable = true;
  };

  services = {
    dbus.enable = true;
  };

  users.users.${primaryUser} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
    ];
    shell =
      if zshEnabled then
        pkgs.zsh
      else if fishEnabled then
        pkgs.fish
      else
        pkgs.bashInteractive;
  };

  fonts = lib.mkIf v.desktop.enable {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      dejavu_fonts
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.symbols-only
    ];

    fontconfig = {
      defaultFonts = {
        serif = [
          "DejaVu Serif"
          "Noto Serif CJK SC"
          "Noto Serif CJK JP"
          "Noto Serif CJK KR"
          "Noto Color Emoji"
        ];
        sansSerif = [
          "DejaVu Sans"
          "Noto Sans CJK SC"
          "Noto Sans CJK JP"
          "Noto Sans CJK KR"
          "Noto Color Emoji"
        ];
        monospace = [
          "FiraCode Nerd Font"
          "Hack Nerd Font"
          "Noto Sans Mono CJK SC"
          "Noto Sans Mono CJK JP"
          "Noto Sans Mono CJK KR"
          "Noto Color Emoji"
          "Symbols Nerd Font"
        ];
        emoji = [
          "Noto Color Emoji"
          "Symbols Nerd Font"
        ];
      };
    };
  };

  # Keep system-wide packages minimal; user-facing tooling lives in Home Manager.
  environment.systemPackages = [ pkgs.git ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = v.host.stateVersion.nixos;
}
