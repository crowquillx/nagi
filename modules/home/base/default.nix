{
  lib,
  pkgs,
  vars ? { },
  inputs,
  config,
  ...
}:
let
  # `vars` is fully schema-resolved for published NixOS and standalone Home
  # Manager outputs. Fallback access remains here because this module is also
  # exported for external Home Manager consumers.
  v = vars;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  audioEnabled = get [ "features" "audio" "enable" ] true;
  networkManagerEnabled = get [ "features" "networking" "networkmanager" "enable" ] true;
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
  terminalDefault = get [ "features" "terminals" "default" ] "kitty";
  alacrittyEnabled = get [ "features" "terminals" "alacritty" "enable" ] true;
  footEnabled = get [ "features" "terminals" "foot" "enable" ] true;
  ghosttyEnabled = get [ "features" "terminals" "ghostty" "enable" ] true;
  kittyEnabled = get [ "features" "terminals" "kitty" "enable" ] true;
  fishEnabled = get [ "features" "shell" "fish" "enable" ] true;
  zshEnabled = get [ "features" "shell" "zsh" "enable" ] false;
  sessionShellLib = import ../desktop/session-shell/lib.nix { inherit lib vars; };
  noctaliaEnabled = sessionShellLib.noctaliaEnable;
  sessionShellName = sessionShellLib.sessionShell;
  restartShellBodyFish =
    if sessionShellName == "noctalia" then
      ''
        if systemctl --user list-unit-files noctalia.service --no-legend 2>/dev/null | read -l unit
          systemctl --user restart noctalia.service
          return
        end

        pkill -u $USER -x noctalia 2>/dev/null
        nohup nagi-noctalia-shell >/dev/null 2>&1 &
        disown
      ''
    else if sessionShellName == "dms" then
      ''
        if systemctl --user list-unit-files dms.service --no-legend 2>/dev/null | read -l unit
          systemctl --user restart dms.service
          return
        end

        pkill -u $USER -f 'dms run' 2>/dev/null
        nohup dms run >/dev/null 2>&1 &
        disown
      ''
    else if sessionShellName == "caelestia" then
      ''
        if systemctl --user list-unit-files caelestia.service --no-legend 2>/dev/null | read -l unit
          systemctl --user restart caelestia.service
          return
        end

        pkill -u $USER -f caelestia-shell 2>/dev/null
        nohup caelestia shell -d >/dev/null 2>&1 &
        disown
      ''
    else if sessionShellName == "inir" then
      ''
        if systemctl --user list-unit-files inir.service --no-legend 2>/dev/null | read -l unit
          systemctl --user restart inir.service
          return
        end

        pkill -u $USER -f 'inir run' 2>/dev/null
        nohup inir run >/dev/null 2>&1 &
        disown
      ''
    else if sessionShellName == "ii" then
      ''
        pkill -u $USER -f 'qs -c ii' 2>/dev/null
        nohup ii >/dev/null 2>&1 &
        disown
      ''
    else
      null;
  restartShellBodyZsh =
    if sessionShellName == "noctalia" then
      ''
        restart-shell() {
          if systemctl --user list-unit-files noctalia.service --no-legend 2>/dev/null | read -r _; then
            systemctl --user restart noctalia.service
            return
          fi

          pkill -u "$USER" -x noctalia 2>/dev/null
          nohup nagi-noctalia-shell >/dev/null 2>&1 &
          disown
        }
        restart-noctalia() { restart-shell; }
      ''
    else if sessionShellName == "dms" then
      ''
        restart-shell() {
          if systemctl --user list-unit-files dms.service --no-legend 2>/dev/null | read -r _; then
            systemctl --user restart dms.service
            return
          fi

          pkill -u "$USER" -f 'dms run' 2>/dev/null
          nohup dms run >/dev/null 2>&1 &
          disown
        }
      ''
    else if sessionShellName == "caelestia" then
      ''
        restart-shell() {
          if systemctl --user list-unit-files caelestia.service --no-legend 2>/dev/null | read -r _; then
            systemctl --user restart caelestia.service
            return
          fi

          pkill -u "$USER" -f caelestia-shell 2>/dev/null
          nohup caelestia shell -d >/dev/null 2>&1 &
          disown
        }
      ''
    else if sessionShellName == "inir" then
      ''
        restart-shell() {
          if systemctl --user list-unit-files inir.service --no-legend 2>/dev/null | read -r _; then
            systemctl --user restart inir.service
            return
          fi

          pkill -u "$USER" -f 'inir run' 2>/dev/null
          nohup inir run >/dev/null 2>&1 &
          disown
        }
      ''
    else if sessionShellName == "ii" then
      ''
        restart-shell() {
          pkill -u "$USER" -f 'qs -c ii' 2>/dev/null
          nohup ii >/dev/null 2>&1 &
          disown
        }
      ''
    else
      "";
  configuredFlakeDirectory = get [ "users" "flakeDirectory" ] null;
  flakeDirectory =
    if configuredFlakeDirectory == null then
      "${config.home.homeDirectory}/nagi"
    else
      configuredFlakeDirectory;

  zenPkg = lib.attrByPath [ "zen-browser" "packages" system "default" ] null inputs;
  zenDesktopFile =
    if zenPkg == null then
      "zen.desktop"
    else if (zenPkg.pname or "") == "zen-beta" then
      "zen-beta.desktop"
    else
      zenPkg.meta.desktopFileName or "zen.desktop";
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

  # helium2nix wraps the launcher with DefaultANGLEVulkan, which corrupts
  # rendering on NVIDIA + Wayland. Re-wrap to pin ANGLE onto native GL while
  # keeping GPU acceleration.
  heliumWrapped =
    if heliumPkg == null then
      null
    else
      pkgs.symlinkJoin {
        name = "${heliumPkg.name}-angle-gl";
        paths = [ heliumPkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          mv $out/bin/helium $out/bin/.helium-unwrapped
          makeWrapper $out/bin/.helium-unwrapped $out/bin/helium \
            --add-flags '--use-gl=angle --use-angle=gl'
        '';
      };

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
    zen = zenDesktopFile;
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
  terminalEnabledMap = {
    alacritty = alacrittyEnabled;
    foot = footEnabled;
    ghostty = ghosttyEnabled;
    kitty = kittyEnabled;
  };
  terminalCommandMap = {
    alacritty = "alacritty";
    foot = "foot";
    ghostty = "ghostty";
    kitty = "kitty";
  };
  terminalDesktopMap = {
    alacritty = "Alacritty.desktop";
    foot = "foot.desktop";
    ghostty = "com.mitchellh.ghostty.desktop";
    kitty = "kitty.desktop";
  };
  terminalCommand = lib.attrByPath [ terminalDefault ] "kitty" terminalCommandMap;
  terminalDesktopFile = lib.attrByPath [ terminalDefault ] "kitty.desktop" terminalDesktopMap;
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
      assertion = lib.attrByPath [ terminalDefault ] false terminalEnabledMap;
      message = "features.terminals.default is \"${terminalDefault}\" but features.terminals.${terminalDefault}.enable is false.";
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
    stateVersion = get [ "host" "stateVersion" "home" ] "25.05";
    packages =
      lib.optionals desktopEnabled (
        with pkgs;
        [
          fuzzel
          wl-clipboard
          cliphist
        ]
      )
      ++ lib.optionals (desktopEnabled && audioEnabled) [ pkgs.pavucontrol ]
      ++ lib.optionals desktopEnabled (
        with pkgs;
        [
          brightnessctl
          playerctl
          grim
          slurp
        ]
      )
      ++ lib.optionals (desktopEnabled && networkManagerEnabled) [ pkgs.networkmanagerapplet ]
      ++ (with pkgs; [
        # General user tooling should be HM-managed.
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
      ++ lib.optionals (heliumEnabled && heliumWrapped != null) [ heliumWrapped ]
      ++ lib.optionals mullvadBrowserEnabled [ pkgs.mullvad-browser ]
      ++ lib.optionals desktopEnabled [
        pkgs.libnotify
      ];
    sessionVariables = {
      NAGI_FLAKE_DIR = flakeDirectory;
      TERMINAL = terminalCommand;
    };
  };

  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      settings = {
        push.autoSetupRemote = true;
        init.defaultBranch = "main";
        # Prefer SSH for GitHub so headless agents never fall back to the
        # x11-ssh-askpass "Username for 'https://github.com'" dialog.
        url."git@github.com:".insteadOf = "https://github.com/";
      }
      // lib.optionalAttrs (gitUserName != null && gitUserEmail != null) {
        user = {
          name = gitUserName;
          email = gitUserEmail;
        };
      };
    };
    # Keep `gh` clone/fork URLs on SSH. Also wires `gh auth git-credential`
    # as the HTTPS safety net via gitCredentialHelper (default-enabled).
    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
      };
    };
    bash.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    fish = {
      enable = fishEnabled;
      interactiveShellInit = ''
        set -g fish_greeting
      '';
      functions =
        lib.optionalAttrs (restartShellBodyFish != null) {
          restart-shell = {
            body = restartShellBodyFish;
          };
        }
        // lib.optionalAttrs noctaliaEnabled {
          restart-noctalia = {
            body = "restart-shell";
          };
        };
    };
    zsh.initContent = lib.mkIf (zshEnabled && restartShellBodyZsh != "") restartShellBodyZsh;
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      setSessionVariables = false;
    };
    # Avoid repeated activation failures when a previous backup file already exists.
    configFile."user-dirs.dirs".force = true;
    configFile."xfce4/helpers.rc" = lib.mkIf thunarEnabled {
      text = "TerminalEmulator=${terminalCommand}\n";
    };
    mimeApps = {
      enable = true;
      defaultApplications = browserAssociations;
      associations.added = browserAssociations;
    };
    terminal-exec = {
      enable = true;
      settings.default = [ terminalDesktopFile ];
    };
  };

  gtk = lib.mkIf (get [ "desktop" "enable" ] true) {
    enable = true;
  };
}
