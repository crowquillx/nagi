{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  primaryUser = get [ "users" "primary" ] "nagi";
  fishEnabled = get [ "features" "shell" "fish" "enable" ] true;
  maintenance = v.features.nixMaintenance;
in
{
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
      extra-substituters = [
        "https://noctalia.cachix.org"
        "https://comfyui.cachix.org"
        "https://cache.nixos-cuda.org"
        "https://nix-community.cachix.org"
        "https://cache.numtide.com"
      ];
      auto-optimise-store = false;
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

  time.timeZone = get [ "host" "timeZone" ] "America/Chicago";
  i18n.defaultLocale = get [ "host" "locale" ] "en_US.UTF-8";

  boot = {
    loader = {
      systemd-boot = {
        enable = lib.mkDefault (get [ "boot" "systemdBoot" "enable" ] true);
        configurationLimit = lib.mkDefault 7;
        consoleMode = lib.mkDefault "max";
      };
      efi.canTouchEfiVariables = lib.mkDefault true;
    };

    kernelPackages =
      let
        kernel = get [ "boot" "kernel" ] "default";
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
    shell = if fishEnabled then pkgs.fish else pkgs.bashInteractive;
  };

  fonts = {
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

  system.stateVersion = "25.05";
}
