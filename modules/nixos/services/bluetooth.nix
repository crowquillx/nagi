{ lib, config, ... }:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
  inherit (v.features.bluetooth) enable powerOnBoot;
  inherit (v.desktop) compositor extraCompositors;
  compositors = [ compositor ] ++ extraCompositors;
  hasPlasma = builtins.elem "plasma" compositors;
  hasGtkSession = builtins.any (
    c:
    builtins.elem c [
      "niri"
      "hyprland"
    ]
  ) compositors;
  # Plasma ships bluedevil. Blueman is the tray for niri/hyprland. Starting
  # both on a KDE session fights BlueZ and SIGSEGVs the applet (GTK file
  # monitor vs kde-gtk-config rewriting gtk.css).
  enableBlueman = hasGtkSession || !hasPlasma;
in
{
  config = lib.mkMerge [
    (lib.mkIf (desktopEnabled && enable) {
      hardware.bluetooth = {
        enable = true;
        inherit powerOnBoot;
      };
      services.blueman.enable = enableBlueman;
    })
    (lib.mkIf (desktopEnabled && enable && enableBlueman && hasPlasma) {
      # Mixed hosts still install Blueman for Niri/Hyprland.
      environment.etc."xdg/autostart/blueman.desktop".text = ''
        [Desktop Entry]
        Name=Blueman Applet
        Comment=Blueman Bluetooth Manager
        Icon=blueman
        Exec=blueman-applet
        Terminal=false
        Type=Application
        NotShowIn=KDE;
      '';
    })
  ];
}
