{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  primaryUser = v.users.primary;

  vmHostEnable = v.features.virtualisation.vmHost.enable;
  spiceUSBRedirectionEnable = v.features.virtualisation.vmHost.spiceUSBRedirection.enable;
  podmanEnable = v.features.virtualisation.containers.podman.enable;
  dockerEnable = v.features.virtualisation.containers.docker.enable;

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
