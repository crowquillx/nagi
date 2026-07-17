{
  lib,
  config,
  pkgs,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  dm = get [ "desktop" "displayManager" ] "auto";
  compositor = get [ "desktop" "compositor" ] "niri";
  sddmEnable = get [ "desktop" "sddm" "enable" ] true;
  sddmWaylandEnable = get [ "desktop" "sddm" "wayland" "enable" ] true;
  sddmTheme = get [ "desktop" "sddm" "theme" ] "sddm-astronaut-theme";
  sddmBackground = get [ "desktop" "sddm" "background" ] null;
  sddmThemeConfig = get [ "desktop" "sddm" "themeConfig" ] { };
  effectiveDm = if dm == "auto" then "sddm" else dm;
  defaultSession = if compositor == "plasma" then "plasma" else "niri";

  stylixEnabled = config.stylix.enable or false;
  scheme = if stylixEnabled then config.stylix.base16Scheme else { };
  fg = scheme.base00 or "232136";
  bg = scheme.base01 or "2a273f";
  text = scheme.base05 or "e0def4";

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
  // lib.optionalAttrs stylixEnabled {
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
