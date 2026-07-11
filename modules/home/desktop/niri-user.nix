{ lib, pkgs, vars ? { }, inputs ? { }, ... }:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasNiri = builtins.elem "niri" ([ compositor ] ++ extraCompositors);
  niriSettings = get [ "desktop" "niri" "settings" ] { };
  niriOutputs = get [ "desktop" "niri" "outputs" ] { };
  niriSettingsBuilder = get [ "desktop" "niri" "settingsBuilder" ] null;
  defaultNiriConfigBuilder = import ./niri/default.nix;
  niriConfigBuilder = get [ "desktop" "niri" "configBuilder" ] defaultNiriConfigBuilder;
  callBuilder = builder:
    if builder == null then
      null
    else if builtins.isFunction builder then
      builder { inherit lib pkgs vars inputs; }
    else
      builder;
  builtNiriSettings = callBuilder niriSettingsBuilder;
  niriConfig = callBuilder niriConfigBuilder;
  effectiveNiriSettings =
    lib.recursiveUpdate
      (lib.recursiveUpdate niriSettings (lib.optionalAttrs (niriOutputs != { }) { outputs = niriOutputs; }))
      (if builtNiriSettings == null then { } else builtNiriSettings);
  hasNiriSettings = effectiveNiriSettings != { };
  hasNiriConfig = niriConfig != null;
  niriPackage = lib.attrByPath [ "niri-unstable" ] null pkgs;
  rosePineCursorPkg = lib.attrByPath [ "rose-pine-cursor" ] null pkgs;
in
{
  config = lib.mkIf (desktopEnabled && hasNiri) (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = rosePineCursorPkg != null;
            message = "Installing the Niri session requires the nixpkgs package 'rose-pine-cursor'.";
          }
        ];

        home.pointerCursor = lib.mkIf (rosePineCursorPkg != null) {
          name = "BreezeX-RosePine-Linux";
          package = rosePineCursorPkg;
          size = 32;
          gtk.enable = true;
          x11.enable = true;
        };

        home.sessionVariables = {
          NIXOS_OZONE_WL = lib.mkDefault "1";
          ELECTRON_OZONE_PLATFORM_HINT = lib.mkDefault "auto";
        };
      }
      (lib.mkIf (niriPackage != null) {
        programs.niri.package = lib.mkDefault niriPackage;
      })
      (lib.mkIf hasNiriConfig {
        programs.niri.config = niriConfig;
      })
      (lib.mkIf (!hasNiriConfig && hasNiriSettings) {
        programs.niri.settings = effectiveNiriSettings;
      })
    ]
  );
}
