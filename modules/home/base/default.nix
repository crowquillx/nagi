{
  lib,
  pkgs,
  vars ? { },
  inputs,
  config,
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  thunarEnabled = get [ "features" "fileManager" "thunar" "enable" ] (
    get [ "desktop" "enable" ] true
  );
  system = pkgs.stdenv.hostPlatform.system;
  gitUserName = get [ "users" "git" "name" ] null;
  gitUserEmail = get [ "users" "git" "email" ] null;
  browserDefault = get [ "desktop" "browser" "default" ] "zen";
  zenEnabled = get [ "desktop" "browser" "zen" "enable" ] false;
  heliumEnabled = get [ "desktop" "browser" "helium" "enable" ] false;
  mullvadBrowserEnabled = get [ "desktop" "browser" "mullvadBrowser" "enable" ] false;
  alacrittyEnabled = get [ "features" "terminals" "alacritty" "enable" ] true;
  footEnabled = get [ "features" "terminals" "foot" "enable" ] true;
  fishEnabled = get [ "features" "shell" "fish" "enable" ] true;
  noctaliaEnabled = get [ "desktop" "noctalia" "enable" ] false;
  configuredFlakeDirectory = get [ "users" "flakeDirectory" ] null;
  flakeDirectory =
    if configuredFlakeDirectory == null
    then "${config.home.homeDirectory}/nagi"
    else configuredFlakeDirectory;

  zenPkg = lib.attrByPath [ "zen-browser" "packages" system "default" ] null inputs;
  thunarPkg =
    let
      topLevelPkg = lib.attrByPath [ "thunar" ] null pkgs;
      archivePlugin = lib.attrByPath [ "thunar-archive-plugin" ] null pkgs;
    in
    if topLevelPkg != null && archivePlugin != null then
      topLevelPkg.override { thunarPlugins = [ archivePlugin ]; }
    else
      topLevelPkg;
  archivePluginPkg =
    let
      topLevelPkg = lib.attrByPath [ "thunar-archive-plugin" ] null pkgs;
    in
    topLevelPkg;
  xfconfPkg =
    let
      topLevelPkg = lib.attrByPath [ "xfconf" ] null pkgs;
      xfcePkg = lib.attrByPath [ "xfce" "xfconf" ] null pkgs;
    in
    if topLevelPkg != null then topLevelPkg else xfcePkg;
  archiveManagerPkg =
    let
      fileRoller = lib.attrByPath [ "file-roller" ] null pkgs;
      xarchiver = lib.attrByPath [ "xarchiver" ] null pkgs;
    in
    if fileRoller != null then fileRoller else xarchiver;
  heliumPkg = lib.findFirst (pkg: pkg != null) null [
    (lib.attrByPath [ "helium2nix" "packages" system "default" ] null inputs)
    (lib.attrByPath [ "helium2nix" "packages" system "helium" ] null inputs)
    (lib.attrByPath [ "helium2nix" "packages" system "helium-browser" ] null inputs)
    (lib.attrByPath [ "helium2nix" "defaultPackage" system ] null inputs)
  ];

  allowedBrowsers = [
    "zen"
    "helium"
    "mullvadBrowser"
  ];
  browserEnabledMap = {
    zen = zenEnabled;
    helium = heliumEnabled;
    mullvadBrowser = mullvadBrowserEnabled;
  };
  browserPackageMap = {
    zen = zenPkg;
    helium = heliumPkg;
    mullvadBrowser = pkgs.mullvad-browser;
  };
  desktopFileFor =
    pkg: fallback: if pkg == null then fallback else (pkg.meta.desktopFileName or fallback);
  browserDesktopMap = {
    zen = desktopFileFor zenPkg "zen.desktop";
    helium = desktopFileFor heliumPkg "helium.desktop";
    mullvadBrowser = desktopFileFor pkgs.mullvad-browser "mullvad-browser.desktop";
  };
  browserPkg = lib.attrByPath [ browserDefault ] null browserPackageMap;
  browserDesktopFile = lib.attrByPath [ browserDefault ] "zen.desktop" browserDesktopMap;
  browserMimeTypes = [
    "application/xhtml+xml"
    "text/html"
    "x-scheme-handler/about"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/unknown"
  ];
  browserAssociations = builtins.listToAttrs (
    map (mime: {
      name = mime;
      value = browserDesktopFile;
    }) browserMimeTypes
  );
in
{
  assertions = [
    {
      assertion = builtins.elem browserDefault allowedBrowsers;
      message = "Unsupported desktop.browser.default \"${browserDefault}\". Allowed values: zen, helium, mullvadBrowser.";
    }
    {
      assertion = lib.attrByPath [ browserDefault ] false browserEnabledMap;
      message = "desktop.browser.default is \"${browserDefault}\" but desktop.browser.${browserDefault}.enable is false.";
    }
    {
      assertion = !(zenEnabled && zenPkg == null);
      message = "desktop.browser.zen.enable is true, but zen-browser package could not be resolved from flake input.";
    }
    {
      assertion = !(heliumEnabled && heliumPkg == null);
      message = "desktop.browser.helium.enable is true, but helium2nix package could not be resolved from flake input.";
    }
    {
      assertion = !(browserDefault == "helium" && browserPkg == null);
      message = "desktop.browser.default = \"helium\" requires a resolvable helium2nix package.";
    }
    {
      assertion = (gitUserName == null) == (gitUserEmail == null);
      message = "Set both users.git.name and users.git.email (or leave both unset).";
    }
    {
      assertion = !(thunarEnabled && thunarPkg == null);
      message = "features.fileManager.thunar.enable is true, but thunar package could not be resolved from nixpkgs.";
    }
    {
      assertion = !(thunarEnabled && archivePluginPkg == null);
      message = "features.fileManager.thunar.enable is true, but thunar-archive-plugin package could not be resolved from nixpkgs.";
    }
    {
      assertion = !(thunarEnabled && xfconfPkg == null);
      message = "features.fileManager.thunar.enable is true, but xfconf package could not be resolved from nixpkgs.";
    }
    {
      assertion = !(thunarEnabled && archiveManagerPkg == null);
      message = "features.fileManager.thunar.enable is true, but no archive manager package (file-roller/xarchiver) could be resolved from nixpkgs.";
    }
  ];

  home = {
    stateVersion = "25.05";
    packages =
      (with pkgs; [
        # General user tooling should be HM-managed.
        fuzzel
        wl-clipboard
        cliphist
        pavucontrol
        brightnessctl
        playerctl
        grim
        slurp
        networkmanagerapplet
        fzf
        bat
        eza
        jq
        ripgrep
        fd
        unzip
        zip
        p7zip
        unar
        unrar
        vim
        neovim
        htop
        fastfetch
        wget
        curl
      ])
      ++ lib.optionals alacrittyEnabled [ pkgs.alacritty ]
      ++ lib.optionals footEnabled [ pkgs.foot ]
      ++ lib.optionals (thunarEnabled && thunarPkg != null) [ thunarPkg ]
      ++ lib.optionals (thunarEnabled && xfconfPkg != null) [ xfconfPkg ]
      ++ lib.optionals (thunarEnabled && archiveManagerPkg != null) [ archiveManagerPkg ]
      ++ lib.optionals (zenEnabled && zenPkg != null) [ zenPkg ]
      ++ lib.optionals (heliumEnabled && heliumPkg != null) [ heliumPkg ]
      ++ lib.optionals mullvadBrowserEnabled [ pkgs.mullvad-browser ]
      ++ lib.optionals (get [ "desktop" "enable" ] true) [
        pkgs.libnotify
      ];
    sessionVariables = {
      NAGI_FLAKE_DIR = flakeDirectory;
      QT_STYLE_OVERRIDE = lib.mkForce "";
    };
  };

  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      settings.push.autoSetupRemote = true;
    }
    // lib.optionalAttrs (gitUserName != null && gitUserEmail != null) {
      settings.user = {
        name = gitUserName;
        email = gitUserEmail;
      };
    };
    bash.enable = true;
    fish = {
      enable = fishEnabled;
      interactiveShellInit = ''
        set -g fish_greeting
      '';
      functions = lib.mkIf noctaliaEnabled {
        restart-noctalia = {
          body = ''
            if systemctl --user list-unit-files noctalia.service --no-legend 2>/dev/null | read -l _
              systemctl --user restart noctalia.service
              return
            end

            pkill -u $USER -x noctalia 2>/dev/null
            nohup nagi-noctalia-shell >/dev/null 2>&1 &
            disown
          '';
        };
      };
    };
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      setSessionVariables = false;
    };
    # Avoid repeated activation failures when a previous backup file already exists.
    configFile."user-dirs.dirs".force = true;
    mimeApps = {
      enable = true;
      defaultApplications = browserAssociations;
      associations.added = browserAssociations;
    };
  };

  systemd.user.sessionVariables = {
    QT_STYLE_OVERRIDE = lib.mkForce "";
  };

  gtk = lib.mkIf (get [ "desktop" "enable" ] true) {
    enable = true;
  };
}
