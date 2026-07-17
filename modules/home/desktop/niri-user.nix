# Home-side Niri session wiring.
#
# Extension contract (desktop.niri.*):
# 1. configBuilder (primary)
#    Function `{ lib, pkgs, vars, inputs } -> KDL config` written to
#    `programs.niri.config`. Default: ./niri/default.nix.
#    Set to `null` to use the attrset settings path instead.
# 2. outputs (additive)
#    Structured per-connector overrides. Consumed by the default configBuilder
#    via vars (`desktop.niri.outputs`). On the settings path, merged as
#    `settings.outputs`.
# 3. settings (additive, settings-path only)
#    Opaque attrset for `programs.niri.settings` when `configBuilder == null`.
#
# Precedence when using the settings path:
#   settings  <  outputs  (outputs fully replace the `outputs` key)
#
# When `configBuilder != null` (the default), only the KDL result is applied;
# `settings` is ignored. `outputs` still affect the default builder through vars.
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
  defaultNiriConfigBuilder = import ./niri/default.nix;
  niriConfigBuilder = get [ "desktop" "niri" "configBuilder" ] defaultNiriConfigBuilder;

  callBuilder = builder:
    if builder == null then
      null
    else if builtins.isFunction builder then
      builder { inherit lib pkgs vars inputs; }
    else
      builder;

  niriConfig = callBuilder niriConfigBuilder;

  # Settings-path merge: base settings, then outputs replace settings.outputs.
  effectiveNiriSettings =
    niriSettings // lib.optionalAttrs (niriOutputs != { }) { outputs = niriOutputs; };

  hasNiriSettings = effectiveNiriSettings != { };
  hasNiriConfig = niriConfig != null;

  niriPackage = lib.attrByPath [ "niri-unstable" ] null pkgs;
  cursorTheme = import ./cursor-theme.nix;
  rosePineCursorPkg = lib.attrByPath [ cursorTheme.packageAttr ] null pkgs;
in
{
  config = lib.mkIf (desktopEnabled && hasNiri) (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = rosePineCursorPkg != null;
            message = "Installing the Niri session requires the nixpkgs package '${cursorTheme.packageAttr}'.";
          }
        ];

        home.pointerCursor = lib.mkIf (rosePineCursorPkg != null) {
          enable = true;
          inherit (cursorTheme) name size;
          package = rosePineCursorPkg;
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
