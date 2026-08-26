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
  hasPlasma = builtins.elem "plasma" ([ compositor ] ++ extraCompositors);
  klassyPkg = lib.attrByPath [ "klassy" ] null pkgs;
  betterBlurDxPkg = lib.attrByPath [ "kwin-effects-better-blur-dx" ] null pkgs;
  stylixVariant = v.features.stylix.variant;
  rosePine = import ../../theme/rose-pine.nix;
  colorScheme = import ../../theme/plasma-color-scheme.nix {
    inherit lib;
    variant = stylixVariant;
    colors = rosePine.${stylixVariant};
  };
  colorSchemePkg = pkgs.writeTextFile {
    name = "nagi-${lib.toLower colorScheme.slug}-plasma-colors";
    destination = "/share/color-schemes/${colorScheme.slug}.colors";
    inherit (colorScheme) text;
  };
in
{
  config = lib.mkIf (desktopEnabled && hasPlasma) {
    assertions = [
      {
        assertion = klassyPkg != null;
        message = "pkgs.klassy is unavailable; Plasma installs Klassy as its window decoration and application style.";
      }
      {
        assertion = betterBlurDxPkg != null;
        message = "pkgs.kwin-effects-better-blur-dx is unavailable; Plasma installs Better Blur DX as a KWin effect.";
      }
    ];

    services.desktopManager.plasma6.enable = true;

    # SDDM includes login, so login is the session that actually unlocks
    # the wallet. kde covers the screen locker. forceRun still unlocks when
    # the wallet password is empty or pam_kwallet's pre-checks would skip.
    security.pam.services = {
      login.kwallet = {
        enable = true;
        forceRun = lib.mkForce true;
      };
      kde.kwallet = {
        enable = true;
        forceRun = lib.mkForce true;
      };
    };

    # kdotool drives KWin's scripting API over DBus; used to bind shortcuts
    # that act on the focused window (e.g. force-kill without the pick cursor).
    environment.systemPackages = [
      pkgs.kdotool
      colorSchemePkg
    ]
    ++ lib.optionals (klassyPkg != null) [ klassyPkg ]
    ++ lib.optionals (betterBlurDxPkg != null) [ betterBlurDxPkg ];
  };
}
