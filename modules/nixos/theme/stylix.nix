{ lib, config, ... }:
let
  v = config.nagi.variables;

  variantRaw = v.features.stylix.variant;
  allowedVariants = [
    "moon"
    "main"
    "dawn"
  ];
  schemes = import ../../theme/rose-pine.nix;

  stylixPolicy = import ../../theme/stylix-enabled.nix {
    inherit lib;
    vars = v;
  };
  enabled = stylixPolicy.enable;
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
        }
        // lib.optionalAttrs stylixPolicy.plasmaOnly (
          lib.removeAttrs stylixPolicy.plasmaOwnedTargets [ "kde" ]
        );
      };
    })
  ];
}
