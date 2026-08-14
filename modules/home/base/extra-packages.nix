{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  packageNames = get [ "users" "extraPackages" ] [ ];
  localsendEnabled = get [ "features" "localsend" "package" "enable" ] false;
  mullvadPackage = get [ "features" "mullvad" "package" ] "none";
  chatClient = get [ "features" "chat" "client" ] "none";
  bravePasswordStore = get [ "desktop" "browser" "brave" "passwordStore" ] "auto";
  bravePackage =
    if bravePasswordStore == "auto" then
      pkgs.brave
    else
      pkgs.brave.overrideAttrs (old: {
        preFixup = (old.preFixup or "") + ''
          gappsWrapperArgs+=(--add-flags "--password-store=${bravePasswordStore}")
        '';
      });
  discordForceXwayland = get [ "features" "chat" "discord" "forceXwayland" ] true;
  equicordEnabled = get [ "features" "chat" "discord" "equicord" "enable" ] false;
  # pkgs.discord is now an FHSEnv wrapper without /opt/Discord. Use the
  # upstream hook so Equicord is patched into discord-unwrapped.
  discordBasePackage =
    if equicordEnabled then pkgs.discord.override { withEquicord = true; } else pkgs.discord;
  discordPackage =
    if discordForceXwayland then
      pkgs.symlinkJoin {
        name = "discord-xwayland";
        paths = [ discordBasePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm -f "$out/bin/discord" "$out/bin/Discord"
          makeWrapper "${discordBasePackage}/bin/discord" "$out/bin/discord" \
            --unset NIXOS_OZONE_WL \
            --unset ELECTRON_OZONE_PLATFORM_HINT \
            --add-flags "--ozone-platform=x11"
          makeWrapper "${discordBasePackage}/bin/Discord" "$out/bin/Discord" \
            --unset NIXOS_OZONE_WL \
            --unset ELECTRON_OZONE_PLATFORM_HINT \
            --add-flags "--ozone-platform=x11"
        '';
      }
    else
      discordBasePackage;

  resolvePkg =
    name: if name == "brave" then bravePackage else lib.attrByPath (lib.splitString "." name) null pkgs;
  missingPackageNames = lib.filter (name: resolvePkg name == null) packageNames;
  resolvedPackages = lib.filter (pkg: pkg != null) (map resolvePkg packageNames);
  featurePackages =
    lib.optionals localsendEnabled [ pkgs.localsend ]
    ++ lib.optionals (mullvadPackage == "cli") [ pkgs.mullvad ]
    ++ lib.optionals (mullvadPackage == "gui") [ (lib.getAttr "mullvad-vpn" pkgs) ]
    ++ lib.optionals (chatClient == "discord") [ discordPackage ]
    ++ lib.optionals (chatClient == "equibop") [ pkgs.equibop ];
in
{
  assertions = [
    {
      assertion = missingPackageNames == [ ];
      message = "Unknown users.extraPackages entries: ${lib.concatStringsSep ", " missingPackageNames}";
    }
    {
      assertion = !(localsendEnabled && builtins.elem "localsend" packageNames);
      message = "LocalSend is declared twice; use features.localsend.package.enable instead of users.extraPackages.";
    }
    {
      assertion =
        !(
          mullvadPackage != "none"
          && builtins.any (
            name:
            builtins.elem name [
              "mullvad"
              "mullvad-vpn"
            ]
          ) packageNames
        );
      message = "Mullvad is declared twice; use features.mullvad.package instead of users.extraPackages.";
    }
    {
      assertion = !(chatClient != "none" && builtins.elem chatClient packageNames);
      message = "Chat client is declared twice; use features.chat.client instead of users.extraPackages.";
    }
    {
      assertion = !(equicordEnabled && builtins.elem "equicord" packageNames);
      message = "Equicord is declared twice; use features.chat.discord.equicord.enable instead of users.extraPackages.";
    }
    {
      assertion = !equicordEnabled || chatClient == "discord";
      message = "features.chat.discord.equicord.enable requires features.chat.client = \"discord\"; Equicord cannot be used with Equibop.";
    }
  ];

  home.packages = resolvedPackages ++ featurePackages;
}
