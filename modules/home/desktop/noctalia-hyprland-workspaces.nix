{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  shell = import ./session-shell/lib.nix { inherit lib vars; };
  inherit (shell) hasHyprland noctaliaEnable;

  hyprlandOutputs = get [ "desktop" "hyprland" "outputs" ] { };
  workspaceOutputs = lib.filterAttrs (
    _: output: (output.workspaceBase or null) != null
  ) hyprlandOutputs;
  hasWorkspaceBases = workspaceOutputs != { };

  # null (default) auto-enables when Hyprland local bases exist; bool forces on/off.
  pluginEnableRaw = get [ "desktop" "noctalia" "hyprlandLocalWorkspaces" "enable" ] null;
  pluginEnable =
    if pluginEnableRaw == null then
      noctaliaEnable && hasHyprland && hasWorkspaceBases
    else
      pluginEnableRaw;

  pluginPkg = pkgs.callPackage ../../../pkgs/noctalia-plugins/hyprland-local-workspaces { };

  workspaceBases = lib.mapAttrs (_: output: toString output.workspaceBase) workspaceOutputs;

  pluginId = pluginPkg.passthru.pluginId;
  widgetType = pluginPkg.passthru.widgetType;
  pluginDirName = pluginPkg.passthru.pluginDirName;

  # settings.toml wins over config.toml for arrays. Ensure the plugin stays in
  # the enabled list without clobbering other GUI-managed plugin toggles.
  ensurePluginEnabled = pkgs.writeShellScript "nagi-noctalia-ensure-hyprland-local-workspaces" ''
    set -eu
    settings="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"
    plugin_id=${lib.escapeShellArg pluginId}

    if [ ! -f "$settings" ]; then
      mkdir -p "$(dirname "$settings")"
      printf '%s\n' '[plugins]' "enabled = [\"$plugin_id\"]" >"$settings"
      exit 0
    fi

    ${pkgs.python3}/bin/python - "$settings" "$plugin_id" <<'PY'
    import pathlib
    import re
    import sys

    path = pathlib.Path(sys.argv[1])
    plugin_id = sys.argv[2]
    text = path.read_text(encoding="utf-8")

    # Slice the [plugins] table: from its header to the next top-level [table].
    header = re.search(r'(?m)^\[plugins\]\s*$', text)
    if header is None:
        if text and not text.endswith("\n"):
            text += "\n"
        text += f"\n[plugins]\nenabled = [\"{plugin_id}\"]\n"
        path.write_text(text, encoding="utf-8")
        raise SystemExit(0)

    start = header.start()
    rest = text[header.end() :]
    next_table = re.search(r'(?m)^\[[^\]]+\]\s*$', rest)
    end = header.end() + (next_table.start() if next_table else len(rest))
    section = text[start:end]

    enabled_match = re.search(r'(?ms)^enabled\s*=\s*\[(.*?)\]', section)
    if enabled_match is None:
        # Insert before the trailing newline that precedes the next table, if any.
        insert_at = len(section.rstrip("\n"))
        new_section = section[:insert_at] + f'\nenabled = ["{plugin_id}"]' + section[insert_at:]
        if not new_section.endswith("\n"):
            new_section += "\n"
    else:
        body = enabled_match.group(1)
        if plugin_id in body:
            raise SystemExit(0)
        body = body.strip()
        new_body = f'"{plugin_id}"' if body == "" else body.rstrip() + f', "{plugin_id}"'
        new_section = (
            section[: enabled_match.start()]
            + f"enabled = [{new_body}]"
            + section[enabled_match.end() :]
        )

    new_text = text[:start] + new_section + text[end:]
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
    PY
  '';
in
{
  config = lib.mkIf (desktopEnabled && noctaliaEnable && pluginEnable) {
    assertions = [
      {
        assertion = hasHyprland;
        message = "desktop.noctalia.hyprlandLocalWorkspaces requires the hyprland compositor.";
      }
      {
        assertion = hasWorkspaceBases;
        message = "desktop.noctalia.hyprlandLocalWorkspaces requires at least one desktop.hyprland.outputs.*.workspaceBase.";
      }
    ];

    # Local plugin drop-in: always scanned by Noctalia as the built-in "local"
    # source, so we never replace official/community [[plugins.source]] entries.
    xdg.dataFile."noctalia/plugins/${pluginDirName}".source = "${pluginPkg}/${pluginDirName}";

    programs.noctalia.settings =
      let
        widgetSettings = {
          type = widgetType;
          hide_when_empty = false;
          gap = 4;
          poll_ms = 250;
          workspace_bases = workspaceBases;
          focused_color = "primary";
          occupied_color = "secondary";
          empty_color = "secondary";
          urgent_color = "error";
        };
      in
      {
        plugins.enabled = [ pluginId ];

        # Cover both the default name and a GUI-renamed instance ("bar").
        widget.workspaces = widgetSettings;
        widget.bar = widgetSettings;
      };

    home.activation.nagiNoctaliaHyprlandLocalWorkspaces = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${ensurePluginEnabled}
    '';
  };
}
