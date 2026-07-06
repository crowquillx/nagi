{ lib, pkgs, vars ? { }, ... }:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "davinciResolve" "enable" ] false;
  variant = get [ "features" "davinciResolve" "variant" ] "free";
  desktopEnabled = get [ "desktop" "enable" ] true;
  graphicsProfile = get [ "graphics" "profile" ] "auto";
  hostIsVm = get [ "host" "isVm" ] false;
  effectiveGraphicsProfile =
    if graphicsProfile == "auto" then
      if hostIsVm then "vm" else "none"
    else
      graphicsProfile;
  nvidiaEnabled = effectiveGraphicsProfile == "nvidia";
  waylandCompat = desktopEnabled && get [ "features" "davinciResolve" "waylandCompat" ] true;

  basePackage =
    if variant == "studio" then
      pkgs.davinci-resolve-studio or null
    else if variant == "free" then
      pkgs.davinci-resolve or null
    else
      null;

  mainProgram =
    if basePackage != null then
      basePackage.meta.mainProgram or basePackage.pname
    else
      if variant == "studio" then "davinci-resolve-studio" else "davinci-resolve";

  wrappedPackage =
    if basePackage == null then
      null
    else if !(waylandCompat || nvidiaEnabled) then
      basePackage
    else
      pkgs.symlinkJoin {
        name = "${basePackage.pname}-session-compat";
        paths = [ basePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          if [ -x "$out/bin/${mainProgram}" ]; then
            mv "$out/bin/${mainProgram}" "$out/bin/.${mainProgram}-unwrapped"
            makeWrapper "$out/bin/.${mainProgram}-unwrapped" "$out/bin/${mainProgram}" \
              ${lib.optionalString waylandCompat ''
                --set QT_QPA_PLATFORM xcb \
                --set UBUNTU_MENUPROXY 0 \
              ''}
              ${lib.optionalString nvidiaEnabled ''
                --set __GLX_VENDOR_LIBRARY_NAME nvidia \
                --set __NV_PRIME_RENDER_OFFLOAD 1 \
                --set __VK_LAYER_NV_optimus NVIDIA_only \
              ''}
          fi
        '';
      };
in
{
  assertions = [
    {
      assertion = builtins.elem variant [ "free" "studio" ];
      message = "features.davinciResolve.variant must be \"free\" or \"studio\".";
    }
    {
      assertion = !enabled || basePackage != null;
      message =
        if variant == "studio" then
          "features.davinciResolve.enable is true, but nixpkgs package 'davinci-resolve-studio' could not be resolved."
        else
          "features.davinciResolve.enable is true, but nixpkgs package 'davinci-resolve' could not be resolved.";
    }
    {
      assertion = !(enabled && builtins.elem mainProgram (get [ "users" "extraPackages" ] [ ]));
      message = "DaVinci Resolve is declared twice; use features.davinciResolve.enable instead of users.extraPackages.";
    }
  ];

  home.packages = lib.optionals enabled (lib.filter (pkg: pkg != null) [ wrappedPackage ]);
}
