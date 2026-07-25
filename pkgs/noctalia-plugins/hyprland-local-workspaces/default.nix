{
  lib,
  stdenvNoCC,
  hyprland,
}:
let
  hyprctl = lib.getExe' hyprland "hyprctl";
  pluginName = "hyprland-local-workspaces";
in
stdenvNoCC.mkDerivation {
  pname = "nagi-noctalia-hyprland-local-workspaces";
  version = "1.0.2";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  # Path sources scan `<source>/<plugin-dir>/plugin.toml`. Install the plugin
  # as a subdirectory so the derivation root can be used as a plugins.source.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/${pluginName}/translations"
    cp plugin.toml "$out/${pluginName}/plugin.toml"
    cp -r translations/. "$out/${pluginName}/translations/"
    substitute bar.luau "$out/${pluginName}/bar.luau" \
      --replace-fail '@hyprctl@' ${lib.escapeShellArg hyprctl}
    runHook postInstall
  '';

  passthru = {
    pluginId = "nagi/hyprland-local-workspaces";
    widgetType = "nagi/hyprland-local-workspaces:bar";
    pluginDirName = pluginName;
  };

  meta = {
    description = "Noctalia bar plugin: monitor-local Hyprland workspace labels with global ID dispatch";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
