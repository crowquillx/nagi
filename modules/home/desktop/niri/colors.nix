# Niri chrome colors. Historically locked to Rose Pine Main (not stylix.variant).
let
  schemes = import ../../../theme/rose-pine.nix;
  c = schemes.main;
  hex = id: "#${c.${id}}";
in
{
  active = hex "base0A";
  urgent = hex "base08";
  inactive = hex "base00";
  shadow = "${hex "base00"}70";
  insertHint = "${hex "base0A"}80";
  # Tab inactive accent kept as a Niri-specific value (not in the base16 tables).
  tabInactive = "#ce2b24";
}
