{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "laptop" "enable" ] false;

  upowerEnable = get [ "features" "laptop" "upower" "enable" ] true;
  tlpEnable = get [ "features" "laptop" "tlp" "enable" ] true;
  thermaldEnable = get [ "features" "laptop" "thermald" "enable" ] true;
  powertopEnable = get [ "features" "laptop" "powertop" "enable" ] false;
  fwupdEnable = get [ "features" "laptop" "fwupd" "enable" ] true;

  lidSwitch = get [ "features" "laptop" "logind" "lidSwitch" ] "suspend";
  lidSwitchExternalPower = get [ "features" "laptop" "logind" "lidSwitchExternalPower" ] "ignore";
  lidSwitchDocked = get [ "features" "laptop" "logind" "lidSwitchDocked" ] "ignore";
  lockOnLidClose = get [ "desktop" "session" "lock" "onLidClose" ] true;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(enabled && lockOnLidClose) || lidSwitch != "ignore";
          message = "features.laptop.logind.lidSwitch must not be \"ignore\" when desktop.session.lock.onLidClose is true.";
        }
      ];
    }
    (lib.mkIf enabled {
      services = {
        upower.enable = upowerEnable;
        thermald.enable = thermaldEnable;
        tlp.enable = tlpEnable;
        fwupd.enable = fwupdEnable;
        logind.settings = {
          Login = {
            HandleLidSwitch = lidSwitch;
            HandleLidSwitchExternalPower = lidSwitchExternalPower;
            HandleLidSwitchDocked = lidSwitchDocked;
          };
        };
      };
      powerManagement.powertop.enable = powertopEnable;
    })
  ];
}
