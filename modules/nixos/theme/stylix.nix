{ lib, config, ... }:
let
  v = config.nagi.variables;

  enabled = v.features.stylix.enable;
  variantRaw = v.features.stylix.variant;
  allowedVariants = [
    "moon"
    "main"
    "dawn"
  ];
  schemes = import ../../theme/rose-pine.nix;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = builtins.elem variantRaw allowedVariants;
          message = ''
            Invalid features.stylix.variant "${toString variantRaw}".
            Allowed values: ${lib.concatStringsSep ", " allowedVariants}
          '';
        }
      ];
    }
    (lib.mkIf enabled {
      stylix = {
        enable = true;
        autoEnable = true;
        base16Scheme = schemes.${variantRaw};
        polarity = if variantRaw == "dawn" then "light" else "dark";

        targets = {
          grub.enable = false;
        };
      };
    })
  ];
}
