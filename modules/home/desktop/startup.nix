# Shared desktop startup + chat launch resolution for systemd and Niri backends.
{ lib, vars }:
let
  get = path: default: lib.attrByPath path default vars;

  defaultStartupApps = [
    "wl-paste --watch cliphist store"
  ];

  startupBackend = get [ "desktop" "startup" "backend" ] "systemd";
  startupApps = get [ "desktop" "startup" "apps" ] defaultStartupApps;

  chatClient = get [ "features" "chat" "client" ] "none";
  chatStartupEnable = get [ "features" "chat" "startup" "enable" ] (chatClient != "none");
  equicordEnabled = get [ "features" "chat" "discord" "equicord" "enable" ] false;

  chatCommands =
    if chatClient == "discord" then
      [ "sleep 5 && discord" ]
    else if chatClient == "equibop" then
      [ "sleep 5 && equibop" ]
    else
      [ ];

  effectiveStartupApps = startupApps ++ lib.optionals chatStartupEnable chatCommands;
in
{
  inherit
    defaultStartupApps
    startupBackend
    startupApps
    chatClient
    chatStartupEnable
    equicordEnabled
    chatCommands
    effectiveStartupApps
    ;
}
