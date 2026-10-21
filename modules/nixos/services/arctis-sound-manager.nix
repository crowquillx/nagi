{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.nagi.variables.features.audio;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.arctis.enable || cfg.enable;
          message = "features.audio.arctis.enable requires features.audio.enable.";
        }
      ];
    }
    (lib.mkIf cfg.arctis.enable {
      services.arctis-sound-manager = {
        enable = true;
        autostartTray = cfg.arctis.autostartTray;
        # Use the repo overlay build (makeWrapperArgs token fix) instead of the
        # flake's pinned self.packages output, which fails in fixupPhase.
        package = lib.mkForce pkgs.arctis-sound-manager;
      };
    })
  ];
}
