{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;

  allowedProfiles = [
    "auto"
    "none"
    "amd"
    "intel"
    "nvidia"
    "vm"
  ];
  hostIsVm = v.host.isVm;
  profileRaw = v.graphics.profile;
  profile = if profileRaw == "auto" then if hostIsVm then "vm" else "none" else profileRaw;

  extraPackageNames = v.graphics.extraPackages;
  resolvePkg = name: lib.attrByPath (lib.splitString "." name) null pkgs;
  missingPackageNames = lib.filter (name: resolvePkg name == null) extraPackageNames;
  resolvedExtraPackages = lib.filter (pkg: pkg != null) (map resolvePkg extraPackageNames);

  nvidiaModesettingEnable = v.graphics.nvidia.modesetting.enable;
  nvidiaPowerManagementEnable = v.graphics.nvidia.powerManagement.enable;
  nvidiaOpenEnable = v.graphics.nvidia.open;
  nvidiaSettingsEnable = v.graphics.nvidia.nvidiaSettings;
  nvidiaUseLatest = v.graphics.nvidia.useLatestDriver;
  enable32Bit = v.graphics.enable32Bit;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = builtins.elem profileRaw allowedProfiles;
          message = ''
            Invalid graphics.profile "${toString profileRaw}".
            Allowed values: ${lib.concatStringsSep ", " allowedProfiles}
          '';
        }
        {
          assertion = missingPackageNames == [ ];
          message = "Unknown graphics.extraPackages entries: ${lib.concatStringsSep ", " missingPackageNames}";
        }
      ];
    }

    (lib.mkIf (profile != "none") {
      hardware.graphics.enable = lib.mkDefault true;
      hardware.graphics.enable32Bit = lib.mkDefault enable32Bit;
    })

    (lib.mkIf (resolvedExtraPackages != [ ]) {
      hardware.graphics.extraPackages = resolvedExtraPackages;
    })

    (lib.mkIf (profile == "amd") {
      services.xserver.videoDrivers = [ "amdgpu" ];
    })

    (lib.mkIf (profile == "intel") {
      services.xserver.videoDrivers = [ "modesetting" ];
    })

    (lib.mkIf (profile == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      boot.kernelParams = [ "nvidia-drm.modeset=1" ];

      hardware.nvidia = {
        modesetting.enable = nvidiaModesettingEnable;
        powerManagement.enable = nvidiaPowerManagementEnable;
        open = nvidiaOpenEnable;
        nvidiaSettings = nvidiaSettingsEnable;
        package = lib.mkIf nvidiaUseLatest config.boot.kernelPackages.nvidiaPackages.latest;
      };
    })

    (lib.mkIf (profile == "vm") {
      environment.sessionVariables = {
        WLR_RENDERER_ALLOW_SOFTWARE = "1";
        LIBGL_ALWAYS_SOFTWARE = "1";
      };
    })
  ];
}
