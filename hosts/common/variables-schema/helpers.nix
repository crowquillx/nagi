{ lib }:
let
  inherit (lib) mkOption types;
  strictSubmodule = options: types.submodule { inherit options; };
  enableOption =
    description: default:
    mkOption {
      type = types.bool;
      inherit default description;
    };
  packageToggle =
    name: default:
    strictSubmodule {
      enable = enableOption "Enable ${name}." default;
    };
  nullableString =
    description:
    mkOption {
      type = types.nullOr types.str;
      default = null;
      inherit description;
    };
  portOption =
    description: default:
    mkOption {
      type = types.port;
      inherit default description;
    };
  mountSubmodule = strictSubmodule {
    device = mkOption { type = types.nonEmptyStr; };
    mountPoint = mkOption { type = types.nonEmptyStr; };
    fsType = mkOption {
      type = types.nonEmptyStr;
      default = "auto";
    };
    options = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };
  flatpakPackage = types.either types.nonEmptyStr (strictSubmodule {
    appId = mkOption { type = types.nonEmptyStr; };
    bundle = mkOption {
      type = types.nullOr (strictSubmodule {
        url = mkOption { type = types.nonEmptyStr; };
        hash = mkOption { type = types.nonEmptyStr; };
      });
      default = null;
    };
  });
in
{
  inherit
    enableOption
    flatpakPackage
    mountSubmodule
    nullableString
    packageToggle
    portOption
    strictSubmodule
    ;
}
