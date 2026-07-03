{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  primaryUser = get [ "users" "primary" ] "nagi";

  vmHostEnable = get [ "features" "virtualisation" "vmHost" "enable" ] false;
  spiceUSBRedirectionEnable = get [
    "features"
    "virtualisation"
    "vmHost"
    "spiceUSBRedirection"
    "enable"
  ] true;
  podmanEnable = get [ "features" "virtualisation" "containers" "podman" "enable" ] false;
  dockerEnable = get [ "features" "virtualisation" "containers" "docker" "enable" ] false;

  extraGroups = lib.optionals vmHostEnable [ "libvirtd" ] ++ lib.optionals dockerEnable [ "docker" ];
in
{
  config = lib.mkMerge [
    (lib.mkIf vmHostEnable {
      virtualisation.libvirtd.enable = true;
      virtualisation.spiceUSBRedirection.enable = spiceUSBRedirectionEnable;
      programs.virt-manager.enable = true;
      environment.systemPackages = [ pkgs.virt-viewer ];
    })

    (lib.mkIf podmanEnable {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
      };
    })

    (lib.mkIf dockerEnable {
      virtualisation.docker.enable = true;
    })

    (lib.mkIf (extraGroups != [ ]) {
      users.users.${primaryUser}.extraGroups = lib.mkAfter extraGroups;
    })
  ];
}
