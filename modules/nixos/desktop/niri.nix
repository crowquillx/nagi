{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
  inherit (v.desktop) compositor extraCompositors;
  hasNiri = builtins.elem "niri" ([ compositor ] ++ extraCompositors);
  niriPackage = lib.attrByPath [ "niri" ] null pkgs;
in
{
  config = lib.mkIf (desktopEnabled && hasNiri) {
    assertions = [
      {
        assertion = niriPackage != null;
        message = "pkgs.niri is unavailable for ${pkgs.stdenv.hostPlatform.system}.";
      }
    ];

    environment.systemPackages = [
      pkgs.xwayland-satellite
    ];

    programs.niri = {
      enable = true;
      package = niriPackage;
    };

    # Full session shells provide the authentication agent. mate-polkit is
    # used only when desktop.sessionShell = "none".
    systemd.user.services.niri-flake-polkit.enable = false;
  };
}
