{
  lib,
  vars ? { },
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasNiri = builtins.elem "niri" ([ compositor ] ++ extraCompositors);
  noctaliaEnable = get [ "desktop" "noctalia" "enable" ] (desktopEnabled && hasNiri);
  kdeThemeEnable = get [ "features" "theme" "qt" "enable" ] true;
  noctaliaSettings = get [ "desktop" "noctalia" "settings" ] { };

  # Required shell defaults win over host settings for the same leaves.
  requiredSettings = {
    shell.polkit_agent = true;
    theme.templates = {
      enable_builtin_templates = true;
      builtin_ids = lib.optionals kdeThemeEnable [ "kcolorscheme" ];
    };
  };
in
{
  config = lib.mkIf (desktopEnabled && hasNiri && noctaliaEnable) {
    programs.noctalia = {
      enable = true;
      systemd.enable = false;
      settings = lib.recursiveUpdate noctaliaSettings requiredSettings;
    };
  };
}
