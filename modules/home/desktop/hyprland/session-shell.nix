{
  lib,
  vars,
  ...
}:
let
  shell = import ../session-shell/lib.nix { inherit lib vars; };
  layerRules =
    if shell.noctaliaEnable then
      ''
        hl.layer_rule({
          name = "noctalia",
          match = {
            namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
          },
          no_anim = true,
          ignore_alpha = 0.5,
          blur = true,
          blur_popups = true,
        })
      ''
    else if shell.dmsEnable then
      ''
        hl.layer_rule({
          name = "dms",
          match = { namespace = "dms" },
          no_anim = true,
        })
      ''
    else if shell.caelestiaEnable then
      ''
        hl.layer_rule({
          name = "caelestia",
          match = { namespace = "^caelestia-" },
          no_anim = true,
        })
      ''
    else if shell.inirEnable then
      ''
        hl.layer_rule({
          name = "inir",
          match = { namespace = "^quickshell" },
          no_anim = true,
        })
      ''
    else if shell.iiEnable then
      ''
        hl.layer_rule({
          name = "ii",
          match = { namespace = "^quickshell" },
          no_anim = true,
        })
      ''
    else
      "";
  includes = lib.optionalString shell.dmsEnable ''
    require("dms.colors")
  '';
in
''
  ${layerRules}
  ${includes}
''
