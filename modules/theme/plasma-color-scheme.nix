# Rose Pine KDE color scheme generated from modules/theme/rose-pine.nix.
# Role mapping follows the hand-tuned Rosé Pine Plasma schemes.
{
  lib,
  variant,
  colors,
}:
let
  rgb =
    hex:
    let
      value = lib.fromHexString hex;
    in
    "${toString (value / 65536)}, ${toString (lib.mod (value / 256) 256)}, ${toString (lib.mod value 256)}";

  meta = {
    moon = {
      slug = "RosePineMoon";
      name = "Rosé Pine Moon";
    };
    main = {
      slug = "RosePine";
      name = "Rosé Pine";
    };
    dawn = {
      slug = "RosePineDawn";
      name = "Rosé Pine Dawn";
    };
  }.${variant};

  window = {
    BackgroundNormal = rgb colors.base00;
    BackgroundAlternate = rgb colors.base01;
    DecorationFocus = rgb colors.base0D;
    DecorationHover = rgb colors.base0C;
    ForegroundActive = rgb colors.base01;
    ForegroundInactive = rgb colors.base04;
    ForegroundLink = rgb colors.base0D;
    ForegroundNegative = rgb colors.base08;
    ForegroundNeutral = rgb colors.base0B;
    ForegroundNormal = rgb colors.base05;
    ForegroundPositive = rgb colors.base0A;
    ForegroundVisited = rgb colors.base0C;
  };

  formatGroup =
    name: attrs:
    "[${name}]\n"
    + lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key}=${toString value}") attrs);

  effectsDisabled = {
    Color = "56,56,56";
    ColorAmount = "0";
    ColorEffect = "0";
    ContrastAmount = "0.65";
    ContrastEffect = "1";
    IntensityAmount = "0.1";
    IntensityEffect = "2";
  };

  effectsInactive = {
    ChangeSelectionColor = "false";
    Color = "112,111,110";
    ColorAmount = "0.025";
    ColorEffect = "2";
    ContrastAmount = "0.1";
    ContrastEffect = "2";
    Enable = "true";
    IntensityAmount = "0";
    IntensityEffect = "0";
  };
in
{
  inherit (meta) slug name;

  text = lib.concatStringsSep "\n\n" [
    (formatGroup "ColorEffects:Disabled" effectsDisabled)
    (formatGroup "ColorEffects:Inactive" effectsInactive)
    (formatGroup "Colors:Button" window)
    (formatGroup "Colors:Complementary" (
      window
      // {
        ForegroundInactive = rgb colors.base0D;
      }
    ))
    (formatGroup "Colors:Header" window)
    (formatGroup "Colors:Header:Inactive" (
      window
      // {
        BackgroundNormal = rgb colors.base01;
        ForegroundNormal = rgb colors.base04;
      }
    ))
    (formatGroup "Colors:Selection" (
      window
      // {
        BackgroundNormal = rgb colors.base0B;
        BackgroundAlternate = rgb colors.base07;
      }
    ))
    (formatGroup "Colors:Tooltip" window)
    (formatGroup "Colors:View" (
      window
      // {
        DecorationHover = rgb colors.base0B;
      }
    ))
    (formatGroup "Colors:Window" window)
    (formatGroup "General" {
      ColorScheme = meta.slug;
      Name = meta.name;
      shadeSortColumn = "false";
    })
    (formatGroup "KDE" {
      contrast = "0";
    })
    (formatGroup "WM" {
      activeBackground = rgb colors.base00;
      activeBlend = rgb colors.base05;
      activeForeground = rgb colors.base05;
      frame = rgb colors.base0C;
      inactiveBackground = rgb colors.base00;
      inactiveBlend = rgb colors.base00;
      inactiveForeground = rgb colors.base05;
      inactiveFrame = rgb colors.base02;
    })
  ];
}
