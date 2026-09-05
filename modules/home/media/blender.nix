{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  blenderEnabled = get [ "features" "blender" "enable" ] false;
  packageNames = get [ "users" "extraPackages" ] [ ];
  blenderPkg = lib.attrByPath [ "blender" ] null pkgs;
in
{
  assertions = [
    {
      assertion = !(blenderEnabled && blenderPkg == null);
      message = "features.blender.enable is true, but nixpkgs package 'blender' could not be resolved.";
    }
    {
      assertion = !(blenderEnabled && builtins.elem "blender" packageNames);
      message = "Blender is declared twice; use features.blender.enable instead of users.extraPackages.";
    }
  ];

  home.packages = lib.optionals (blenderEnabled && blenderPkg != null) [ blenderPkg ];
}
