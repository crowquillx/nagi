{ ... }: {
  imports = [
    ../common/default.nix
    ../profiles/pango.nix
    ./hardware-configuration.nix
  ];
}
