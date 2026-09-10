{
  lib,
  pkgs,
  config,
  inputs,
  modulesPath,
  ...
}:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
  hasUmbriel = v.desktop.compositor == "umbriel";
  umbrielPackage = inputs.umbriel.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  config = lib.mkIf (desktopEnabled && hasUmbriel) (
    lib.mkMerge [
      {
        hardware.graphics.enable = lib.mkDefault true;
        services.displayManager.sessionPackages = [ umbrielPackage ];
        systemd.packages = [ umbrielPackage ];
        systemd.user.services.umbriel = {
          restartIfChanged = false;
          enableDefaultPath = false;
        };
      }
      (import "${modulesPath}/programs/wayland/wayland-session.nix" {
        inherit lib pkgs;
        enableXWayland = false;
        enableWlrPortal = false;
      })
    ]
  );
}
