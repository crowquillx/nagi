{ lib, config, ... }:
let
  v = config.nagi.variables;
  laptop = v.features.laptop;
  enabled = laptop.enable;

  upowerEnable = laptop.upower.enable;
  tlpEnable = laptop.tlp.enable;
  thermaldEnable = laptop.thermald.enable;
  powertopEnable = laptop.powertop.enable;
  fwupdEnable = laptop.fwupd.enable;

  inherit (laptop.logind) lidSwitch lidSwitchDocked lidSwitchExternalPower;
  lockOnLidClose = v.desktop.session.lock.onLidClose;
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
