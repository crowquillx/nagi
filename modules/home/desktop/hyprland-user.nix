{
  lib,
  pkgs,
  vars ? { },
  inputs ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  compositors = [ compositor ] ++ extraCompositors;
  hasHyprland = builtins.elem "hyprland" compositors;
  defaultConfigBuilder = import ./hyprland/default.nix;
  configBuilder = get [ "desktop" "hyprland" "configBuilder" ] defaultConfigBuilder;
  settings = get [ "desktop" "hyprland" "settings" ] { };
  callBuilder =
    builder:
    if builder == null then
      null
    else if builtins.isFunction builder then
      builder {
        inherit
          lib
          pkgs
          vars
          inputs
          ;
      }
    else
      builder;
  luaConfig = callBuilder configBuilder;
in
{
  config = lib.mkIf (desktopEnabled && hasHyprland) (
    lib.mkMerge [
      {
        home = {
          packages = [ pkgs.hyprshot ];

          sessionVariables = {
            NIXOS_OZONE_WL = lib.mkDefault "1";
            ELECTRON_OZONE_PLATFORM_HINT = lib.mkDefault "auto";
          };
        };

        wayland.windowManager.hyprland = {
          enable = true;
          package = null;
          portalPackage = null;
          configType = "lua";
          systemd.enable = false;
          xwayland.enable = true;
        };
      }
      (lib.mkIf (luaConfig != null) {
        wayland.windowManager.hyprland.extraConfig = luaConfig;
      })
      (lib.mkIf (luaConfig == null && settings != { }) {
        wayland.windowManager.hyprland.settings = settings;
      })
    ]
  );
}
