{
  lib,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  enabled = get [ "features" "theme" "qt" "enable" ] true;
  noctaliaSettings = {
    Appearance = {
      color_scheme = "noctalia";
      style = "kvantum";
    };
  };
in
{
  config = lib.mkIf (desktopEnabled && enabled) {
    qt = {
      enable = true;
      platformTheme.name = "qtct";
      style.name = "kvantum";
      qt5ctSettings = noctaliaSettings;
      qt6ctSettings = noctaliaSettings;
    };
  };
}
