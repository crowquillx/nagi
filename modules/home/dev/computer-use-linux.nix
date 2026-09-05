{
  lib,
  pkgs,
  vars ? { },
  config,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  enabled = get [ "features" "mcp" "computerUseLinux" "enable" ] false;
  packageNames = get [ "users" "extraPackages" ] [ ];
  compositors = [
    (get [ "desktop" "compositor" ] "hyprland")
  ]
  ++ get [ "desktop" "extraCompositors" ] [ ];
  hasHyprland = builtins.elem "hyprland" compositors;
  pkg = lib.attrByPath [ "computer-use-linux" ] null pkgs;
  ydotoolPkg = lib.attrByPath [ "ydotool" ] null pkgs;
  waylandTarget = config.wayland.systemd.target;
  wrappedPkg =
    if pkg == null || !hasHyprland then
      pkg
    else
      pkgs.symlinkJoin {
        name = "${pkg.name}-hyprland";
        paths = [ pkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/computer-use-linux" \
            --prefix PATH : ${lib.escapeShellArg (lib.makeBinPath [ pkgs.hyprland ])}
        '';
        inherit (pkg) meta;
      };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(enabled && pkg == null);
          message = "features.mcp.computerUseLinux.enable is true, but package 'computer-use-linux' could not be resolved.";
        }
        {
          assertion = !(enabled && ydotoolPkg == null);
          message = "features.mcp.computerUseLinux.enable is true, but nixpkgs package 'ydotool' could not be resolved.";
        }
        {
          assertion = !(enabled && builtins.elem "computer-use-linux" packageNames);
          message = "computer-use-linux is declared twice; use features.mcp.computerUseLinux.enable instead of users.extraPackages.";
        }
        {
          assertion = !(enabled && builtins.elem "ydotool" packageNames);
          message = "ydotool is declared twice; use features.mcp.computerUseLinux.enable instead of users.extraPackages.";
        }
      ];
    }
    (lib.mkIf (enabled && wrappedPkg != null && ydotoolPkg != null) {
      home.packages = [
        wrappedPkg
        ydotoolPkg
      ];

      home.sessionVariables = {
        GTK_A11Y = "atspi";
        QT_LINUX_ACCESSIBILITY_ALWAYS_ON = "1";
      };
      systemd.user.sessionVariables = {
        GTK_A11Y = "atspi";
        QT_LINUX_ACCESSIBILITY_ALWAYS_ON = "1";
      };

      dconf = {
        enable = true;
        settings."org/gnome/desktop/interface".toolkit-accessibility = true;
      };

      programs.mcp.enable = true;
      programs.mcp.servers.computer-use-linux = {
        command = lib.getExe wrappedPkg;
        args = [ "mcp" ];
      };

      systemd.user.services.ydotoold = {
        Unit = {
          Description = "ydotool user daemon";
          Documentation = "man:ydotool(1) man:ydotoold(8)";
          After = [ waylandTarget ];
          PartOf = [ waylandTarget ];
        };
        Service = {
          ExecStart = "${lib.getExe' ydotoolPkg "ydotoold"} --socket-path=%t/.ydotool_socket --socket-own=%U:%U --socket-perm=0600";
          Restart = "on-failure";
          RestartSec = 1;
        };
        Install.WantedBy = [ waylandTarget ];
      };
    })
  ];
}
