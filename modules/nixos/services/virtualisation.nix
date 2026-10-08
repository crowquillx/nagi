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
  macosBuilderEnable = v.features.virtualisation.macosBuilder.enable;
  libvirtdEnable = vmHostEnable || macosBuilderEnable;
  podmanEnable = v.features.virtualisation.containers.podman.enable;
  dockerEnable = v.features.virtualisation.containers.docker.enable;

  extraGroups =
    lib.optionals libvirtdEnable [ "libvirtd" ]
    ++ lib.optionals macosBuilderEnable [ "kvm" ]
    ++ lib.optionals dockerEnable [ "docker" ];
in
{
  config = lib.mkMerge [
    (lib.mkIf libvirtdEnable {
      virtualisation.libvirtd.enable = true;
      programs.virt-manager.enable = true;
      environment.systemPackages = [ pkgs.virt-viewer ];
    })

    (lib.mkIf vmHostEnable {
      virtualisation.spiceUSBRedirection.enable = spiceUSBRedirectionEnable;
    })

    (lib.mkIf macosBuilderEnable {
      boot.kernelParams = lib.mkAfter [ "kvm.ignore_msrs=1" ];
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
