{
  lib,
  vars ? { },
  inputs,
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  shell = import ./session-shell/lib.nix { inherit lib vars; };
  inherit (shell) noctaliaEnable hasWaylandCompositor;
  noctaliaSettings = get [ "desktop" "noctalia" "settings" ] { };
  noctaliaAssets = "${inputs.noctalia}/assets/templates";

  # These templates only write separate generated files. The main application
  # configs remain owned by Home Manager and include or select those files.
  userTemplates = {
    gtk3 = {
      input_path = "${noctaliaAssets}/gtk/gtk3.css";
      output_path = "$XDG_CONFIG_HOME/gtk-3.0/noctalia.css";
    };
    gtk4 = {
      input_path = "${noctaliaAssets}/gtk/gtk4.css";
      output_path = "$XDG_CONFIG_HOME/gtk-4.0/noctalia.css";
    };
    qt = {
      input_path = "${noctaliaAssets}/qt/qtct.conf";
      output_path = [
        "$XDG_CONFIG_HOME/qt5ct/colors/noctalia.conf"
        "$XDG_CONFIG_HOME/qt6ct/colors/noctalia.conf"
      ];
    };
    ghostty = {
      input_path = "${noctaliaAssets}/ghostty/ghostty";
      output_path = "$XDG_CONFIG_HOME/ghostty/themes/Rose Pine";
    };
    kitty = {
      input_path = "${noctaliaAssets}/kitty/kitty.conf";
      output_path = "$XDG_CONFIG_HOME/kitty/themes/noctalia.conf";
    };
  };

  requiredSettings = {
    shell.polkit_agent = true;
    theme.templates = {
      enable_builtin_templates = true;
      builtin_ids = [
        "kcolorscheme"
        "umbriel"
      ];
      user = userTemplates;
    };
  };
in
{
  config = lib.mkIf (desktopEnabled && hasWaylandCompositor && noctaliaEnable) {
    programs.noctalia = {
      enable = true;
      systemd.enable = false;
      settings = lib.recursiveUpdate noctaliaSettings requiredSettings;
    };
  };
}
