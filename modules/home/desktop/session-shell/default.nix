{
  lib,
  pkgs,
  vars ? { },
  options,
  ...
}:
let
  shell = import ./lib.nix { inherit lib vars; };
  uwsmEnvLines = lib.mapAttrsToList (
    name: value: "export ${name}=${lib.escapeShellArg value}"
  ) shell.toolkitEnv;
  jq = "${pkgs.jq}/bin/jq";
in
{
  config = lib.mkIf shell.desktopEnabled (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = shell.sessionShell != "caelestia" || !shell.hasNiri;
            message = "desktop.sessionShell = \"caelestia\" is illegal when niri is in desktop.compositor or desktop.extraCompositors.";
          }
          {
            assertion = shell.sessionShell != "ii" || !shell.hasNiri;
            message = "desktop.sessionShell = \"ii\" is illegal when niri is in desktop.compositor or desktop.extraCompositors.";
          }
          {
            assertion = shell.noctaliaEnable == (shell.sessionShell == "noctalia");
            message = "desktop.noctalia.enable is derived from desktop.sessionShell == \"noctalia\" and must not be set independently.";
          }
          {
            assertion = builtins.elem shell.sessionShell [
              "noctalia"
              "dms"
              "caelestia"
              "inir"
              "ii"
              "none"
            ];
            message = "desktop.sessionShell must be one of: noctalia, dms, caelestia, inir, ii, none.";
          }
          {
            assertion = !shell.dmsEnable || options.programs ? dank-material-shell;
            message = "desktop.sessionShell = \"dms\" requires the DankMaterialShell Home Manager module from inputs.dms.";
          }
          {
            assertion = !shell.caelestiaEnable || options.programs ? caelestia;
            message = "desktop.sessionShell = \"caelestia\" requires the Caelestia Home Manager module from inputs.caelestia-shell.";
          }
          {
            assertion = !shell.inirEnable || options.programs ? inir;
            message = "desktop.sessionShell = \"inir\" requires the iNiR Home Manager module from inputs.inir.";
          }
        ];
      }
      (lib.mkIf (shell.hasHyprland && shell.toolkitEnv != { }) {
        xdg.configFile."uwsm/env-hyprland".text = lib.concatStringsSep "\n" (uwsmEnvLines ++ [ "" ]);
      })
      (lib.mkIf shell.dmsEnable {
        home.activation.nagi-seed-dms-compositor-includes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "$HOME/.config/niri/dms" "$HOME/.config/hypr/dms"
          [ -e "$HOME/.config/niri/dms/colors.kdl" ] || ${pkgs.coreutils}/bin/touch "$HOME/.config/niri/dms/colors.kdl"
          [ -e "$HOME/.config/niri/dms/layout.kdl" ] || ${pkgs.coreutils}/bin/touch "$HOME/.config/niri/dms/layout.kdl"
          [ -e "$HOME/.config/hypr/dms/colors.lua" ] || ${pkgs.coreutils}/bin/touch "$HOME/.config/hypr/dms/colors.lua"
        '';
      })
      (lib.mkIf (shell.inirEnable || shell.iiEnable) {
        home.activation.nagi-seed-ii-lineage-theming = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          config_dir="$HOME/.config/illogical-impulse"
          config_file="$config_dir/config.json"
          mkdir -p "$config_dir"
          if [ ! -s "$config_file" ]; then
            printf '%s\n' '{}' > "$config_file"
          fi
          already_off="$(
            ${jq} -r '
              if (.appearance.wallpaperTheming.enableAppsAndShell == false)
                 and (.appearance.wallpaperTheming.enableQtApps == false)
                 and (.appearance.wallpaperTheming.enableTerminal == false)
              then "yes" else "no" end
            ' "$config_file" 2>/dev/null || echo no
          )"
          if [ "$already_off" != yes ]; then
            ${jq} '
              .appearance.wallpaperTheming.enableAppsAndShell = false
              | .appearance.wallpaperTheming.enableQtApps = false
              | .appearance.wallpaperTheming.enableTerminal = false
            ' "$config_file" > "$config_file.tmp"
            mv "$config_file.tmp" "$config_file"
          fi
        '';
      })
    ]
  );
}
