# Hand-maintained (originally from nixos-generate-config). The LUKS mapping
# name is fixed to "cryptroot" so host modules never reference a UUID;
# install/reinstall/install.sh rewrites the line after each nagi-*-uuid marker.
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "ext4";
  };

  boot.initrd.luks.devices.cryptroot = {
    # nagi-luks-uuid
    device = "/dev/disk/by-uuid/840bc2c4-3551-4cd7-b379-e0e70db6b623";
  };

  fileSystems."/boot" = {
    # nagi-esp-uuid
    device = "/dev/disk/by-uuid/0C6D-8CA4";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
