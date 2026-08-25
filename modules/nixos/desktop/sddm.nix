{
  lib,
  config,
  pkgs,
  ...
}:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
  dm = v.desktop.displayManager;
  inherit (v.desktop) compositor;
  sddmEnable = v.desktop.sddm.enable;
  sddmWaylandEnable = v.desktop.sddm.wayland.enable;
  sddmTheme = v.desktop.sddm.theme;
  sddmBackground = v.desktop.sddm.background;
  sddmThemeConfig = v.desktop.sddm.themeConfig;
  effectiveDm = if dm == "auto" then "sddm" else dm;
  defaultSession =
    if compositor == "plasma" then
      "plasma"
    else if compositor == "hyprland" then
      "hyprland-uwsm"
    else
      "niri";

  # SDDM colors come straight from the shared Rose Pine scheme by host
  # variant. This does not go through Stylix targets: Plasma-only hosts
  # disable gtk/qt/kde but still share this mapping with stylix.base16Scheme
  # (modules/nixos/theme/stylix.nix).
  scheme = import ../../theme/rose-pine.nix;
  colors = scheme.${v.features.stylix.variant};
  fg = colors.base00;
  bg = colors.base01;
  text = colors.base05;

  sddmBg =
    if sddmBackground != null then
      pkgs.runCommand "sddm-background" {
        outputHashAlgo = "sha256";
        outputHashMode = "flat";
        outputHash = builtins.hashFile "sha256" sddmBackground;
      } "cp ${sddmBackground} $out"
    else
      null;

  themeConfig = {
    HourFormat = "h:mm AP";
    FormPosition = "left";
    Blur = "4.0";
  }
  // lib.optionalAttrs (sddmBg != null) {
    Background = "${sddmBg}";
  }
  // {
    HeaderTextColor = "#${text}";
    DateTextColor = "#${text}";
    TimeTextColor = "#${text}";
    LoginFieldTextColor = "#${text}";
    PasswordFieldTextColor = "#${text}";
    UserIconColor = "#${text}";
    PasswordIconColor = "#${text}";
    WarningColor = "#${text}";
    LoginButtonBackgroundColor = "#${fg}";
    SystemButtonsIconsColor = "#${text}";
    SessionButtonTextColor = "#${text}";
    VirtualKeyboardButtonTextColor = "#${text}";
    DropdownBackgroundColor = "#${bg}";
    HighlightBackgroundColor = "#${text}";
    FormBackgroundColor = "#${bg}";
  }
  // sddmThemeConfig;

  sddmAstronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "pixel_sakura";
    inherit themeConfig;
  };
in
{
  config = lib.mkIf (desktopEnabled && effectiveDm == "sddm" && sddmEnable) {
    services.xserver.enable = true;

    services.displayManager = {
      inherit defaultSession;
      sddm = {
        enable = true;
        package = lib.mkDefault pkgs.kdePackages.sddm;
        wayland.enable = sddmWaylandEnable;
        extraPackages = [ sddmAstronaut ];
        theme = sddmTheme;
      };
    };

    environment.systemPackages = [ sddmAstronaut ];
  };
}
