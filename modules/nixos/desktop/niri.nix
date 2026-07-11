{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasNiri = builtins.elem "niri" ([ compositor ] ++ extraCompositors);
  niriPackage = lib.attrByPath [ "niri-unstable" ] null pkgs;
in
{
  config = lib.mkIf (desktopEnabled && hasNiri) {
    assertions = [
      {
        assertion = niriPackage != null;
        message = "pkgs.niri-unstable is unavailable. Ensure inputs.niri.overlays.niri is applied.";
      }
    ];

    niri-flake.cache.enable = true;

    environment.systemPackages = [
      pkgs.xwayland-satellite
    ];

    programs.niri = {
      enable = true;
      package = niriPackage;
    };

    # Noctalia provides the authentication agent in Niri sessions.
    systemd.user.services.niri-flake-polkit.enable = false;
  };
}
