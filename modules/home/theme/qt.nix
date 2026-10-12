{
  config,
  lib,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  enabled = get [ "features" "theme" "qt" "enable" ] true;
  noctaliaSettings = qtct: {
    Appearance = {
      color_scheme_path = "${config.xdg.configHome}/${qtct}/colors/noctalia.conf";
      custom_palette = true;
      style = "Fusion";
    };
  };
in
{
  config = lib.mkIf (desktopEnabled && enabled) {
    qt = {
      enable = true;
      platformTheme.name = "qtct";
      style.name = "Fusion";
      qt5ctSettings = noctaliaSettings "qt5ct";
      qt6ctSettings = noctaliaSettings "qt6ct";
    };
  };
}
