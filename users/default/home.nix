{ combined, config, lib, vars ? { }, ... }:
let
  get = path: default: lib.attrByPath path default vars;
  configuredFlakeDirectory = get [ "users" "flakeDirectory" ] null;
  flakeDirectory =
    if configuredFlakeDirectory == null
    then "${config.home.homeDirectory}/nagi"
    else configuredFlakeDirectory;
in
{
  imports = combined.homeModules;

  home.file."Pictures/Wallpapers".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/wallpapers";
}
