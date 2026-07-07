{
  lib,
  pkgs,
  vars ? {},
  ...
}: let
  get = path: default: lib.attrByPath path default vars;
  kdenliveEnabled = get ["features" "videoEditing" "kdenlive" "enable"] false;
  davinciResolveEnabled = get ["features" "videoEditing" "davinciResolve" "enable"] false;
  davinciResolveEdition = get ["features" "videoEditing" "davinciResolve" "edition"] "free";
  packageNames = get ["users" "extraPackages"] [];

  kdenlivePkg = lib.attrByPath ["kdePackages" "kdenlive"] null pkgs;
  davinciResolvePackageName =
    if davinciResolveEdition == "studio"
    then "davinci-resolve-studio"
    else "davinci-resolve";
  davinciResolvePkg = lib.attrByPath [davinciResolvePackageName] null pkgs;
in {
  assertions = [
    {
      assertion = !(kdenliveEnabled && kdenlivePkg == null);
      message = "features.videoEditing.kdenlive.enable is true, but nixpkgs package 'kdePackages.kdenlive' could not be resolved.";
    }
    {
      assertion = !(davinciResolveEnabled && davinciResolvePkg == null);
      message = "features.videoEditing.davinciResolve.enable is true, but nixpkgs package '${davinciResolvePackageName}' could not be resolved.";
    }
    {
      assertion = !(kdenliveEnabled && builtins.elem "kdePackages.kdenlive" packageNames);
      message = "Kdenlive is declared twice; use features.videoEditing.kdenlive.enable instead of users.extraPackages.";
    }
    {
      assertion =
        !(
          davinciResolveEnabled
          && builtins.any (name: builtins.elem name ["davinci-resolve" "davinci-resolve-studio"]) packageNames
        );
      message = "DaVinci Resolve is declared twice; use features.videoEditing.davinciResolve instead of users.extraPackages.";
    }
  ];

  home.packages =
    lib.optionals (kdenliveEnabled && kdenlivePkg != null) [kdenlivePkg]
    ++ lib.optionals (davinciResolveEnabled && davinciResolvePkg != null) [davinciResolvePkg];
}
