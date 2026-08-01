{ lib, config, ... }:
let
  cfg = config.nagi.variables.features.razer;
  primaryUser = config.nagi.variables.users.primary;
in
{
  config = lib.mkIf (cfg.openrazer.enable || cfg.inputRemapper.enable) {
    hardware.openrazer = {
      enable = cfg.openrazer.enable;
      users = cfg.openrazer.users;
    };

    services.input-remapper = {
      enable = cfg.inputRemapper.enable;
      enableUdevRules = cfg.inputRemapper.enableUdevRules;
    };

    # input-remapper's GUI starts its reader service via pkexec. NixOS
    # needs the setuid wrapper, and since this host runs without a polkit
    # auth agent, allow the primary user to run exactly the input-remapper
    # binaries without prompting. Matching on argv1 keeps it scoped to
    # input-remapper regardless of the store path.
    security.polkit = lib.mkIf cfg.inputRemapper.enable {
      enablePkexecWrapper = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.policykit.exec" && subject.user == "${primaryUser}") {
            var argv = action.lookup("org.freedesktop.policykit.exec.argv1");
            if (typeof argv === "string" && argv.indexOf("/input-remapper") !== -1) {
              return polkit.Result.YES;
            }
          }
        });
      '';
    };
  };
}
