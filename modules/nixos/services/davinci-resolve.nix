{ lib, pkgs, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "davinciResolve" "enable" ] false;
  variant = get [ "features" "davinciResolve" "variant" ] "free";
  basePackage =
    if variant == "studio" then
      pkgs.davinci-resolve-studio or null
    else
      pkgs.davinci-resolve or null;
in
{
  config = lib.mkIf (enabled && basePackage != null) {
    services.udev.packages = [ basePackage ];
  };
}
