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
  outputTransform =
    types.either
      (types.enum [
        "normal"
        "90"
        "180"
        "270"
        "flipped"
        "flipped-90"
        "flipped-180"
        "flipped-270"
      ])
      (strictSubmodule {
        rotation = mkOption {
          type = types.ints.unsigned;
          default = 0;
        };
        flipped = enableOption "Flip the output horizontally." false;
      });
  outputOptions = {
    enable = enableOption "Enable this output." true;
    mode = mkOption {
      type = strictSubmodule {
        width = mkOption { type = types.ints.positive; };
        height = mkOption { type = types.ints.positive; };
        refresh = mkOption {
          type = types.number;
          default = 60.0;
        };
      };
      default = { };
    };
    scale = mkOption {
      type = types.number;
      default = 1.0;
    };
    transform = mkOption {
      type = outputTransform;
      default = {
        rotation = 0;
        flipped = false;
      };
    };
    position = mkOption {
      type = types.nullOr (strictSubmodule {
        x = mkOption { type = types.int; };
        y = mkOption { type = types.int; };
      });
      default = null;
    };
    variableRefreshRate = mkOption {
      type = types.enum [
        "off"
        "on"
        "on-demand"
      ];
      default = "off";
    };
  };
  outputSubmodule =
    extraOptions:
    strictSubmodule (
      outputOptions
      // {
        focusAtStartup = enableOption "Focus this output when the compositor starts." false;
      }
      // extraOptions
    );
  niriOutputSubmodule = outputSubmodule { };
  hyprlandOutputSubmodule = outputSubmodule {
    workspaceBase = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      description = "Global Hyprland workspace ID offset used to provide monitor-local workspace numbering.";
    };
    bitDepth = mkOption {
      type = types.enum [
        8
        10
      ];
      default = 8;
    };
    colorManagement = mkOption {
      type = types.enum [
        "auto"
        "srgb"
        "dcip3"
        "dp3"
        "adobe"
        "wide"
        "edid"
        "hdr"
        "hdredid"
      ];
      default = "srgb";
    };
    sdrBrightness = mkOption {
      type = types.number;
      default = 1.0;
    };
    sdrSaturation = mkOption {
      type = types.number;
      default = 1.0;
    };
    sdrMaxLuminance = mkOption {
      type = types.ints.positive;
      default = 80;
      description = "Maximum SDR luminance in nits when mapping SDR content to HDR.";
    };
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
    hyprlandOutputSubmodule
    mountSubmodule
    niriOutputSubmodule
    nullableString
    packageToggle
    portOption
    strictSubmodule
    ;
}
