{
  lib,
  pkgs,
  config,
  vars,
  inputs,
  homeModule,
  combined,
  ...
}: let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  primaryUser = get ["users" "primary"] "nagi";
  noctaliaHmModule = lib.attrByPath ["noctalia" "homeModules" "default"] null inputs;
  hmBackupCommand = pkgs.writeShellScript "home-manager-backup" ''
    set -eu

    target_path="$1"
    timestamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
    backup_path="${"$"}{target_path}.hm-backup-${"$"}timestamp"

    while [ -e "$backup_path" ]; do
      timestamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)-$RANDOM"
      backup_path="${"$"}{target_path}.hm-backup-${"$"}timestamp"
    done

    exec ${pkgs.coreutils}/bin/mv "$target_path" "$backup_path"
  '';
in {
  imports =
    [
      ./variables-schema.nix
    ]
    ++ combined.nixosModules;

  nagi.variables = vars;

  assertions = [
    {
      assertion = builtins.isString primaryUser && primaryUser != "";
      message = "users.primary must be a non-empty string.";
    }
    {
      assertion = let
        flakeDirectory = get ["users" "flakeDirectory"] null;
      in
        flakeDirectory == null || (builtins.isString flakeDirectory && flakeDirectory != "");
      message = "users.flakeDirectory must be null or a non-empty string.";
    }
    {
      assertion = let
        extraPackages = get ["users" "extraPackages"] [];
      in
        builtins.isList extraPackages && builtins.all lib.isString extraPackages;
      message = "users.extraPackages must be a list of package attribute strings.";
    }
    {
      assertion = builtins.isBool (get ["desktop" "enable"] true);
      message = "desktop.enable must be a boolean.";
    }
    {
      assertion = let
        compositor = get ["desktop" "compositor"] "niri";
      in
        builtins.elem compositor [
          "niri"
          "plasma"
        ];
      message = "desktop.compositor must be one of: niri, plasma.";
    }
    {
      assertion = let
        extraCompositors = get ["desktop" "extraCompositors"] [];
      in
        builtins.isList extraCompositors
        && builtins.all lib.isString extraCompositors
        && builtins.all (
          c:
            builtins.elem c [
              "niri"
              "plasma"
            ]
        )
        extraCompositors;
      message = "desktop.extraCompositors may only include: niri, plasma.";
    }
    {
      assertion = let
        dm = get ["desktop" "displayManager"] "auto";
      in
        builtins.elem dm [
          "auto"
          "sddm"
        ];
      message = ''
        desktop.displayManager must be one of: auto, sddm.
      '';
    }
    {
      assertion = let
        startupApps = get ["desktop" "startup" "apps"] [];
      in
        builtins.isList startupApps && builtins.all lib.isString startupApps;
      message = "desktop.startup.apps must be a list of command strings.";
    }
    {
      assertion = builtins.isBool (get ["security" "sops" "enable"] true);
      message = "security.sops.enable must be a boolean.";
    }
    {
      assertion = let
        defaultSopsFile = get ["security" "sops" "defaultSopsFile"] null;
      in
        defaultSopsFile == null
        || (builtins.isString defaultSopsFile && defaultSopsFile != "")
        || builtins.isPath defaultSopsFile;
      message = "security.sops.defaultSopsFile must be null or a non-empty string/path.";
    }
    {
      assertion = let
        ageKeyFile = get ["security" "sops" "ageKeyFile"] null;
      in
        ageKeyFile == null || (builtins.isString ageKeyFile && ageKeyFile != "");
      message = "security.sops.ageKeyFile must be null or a non-empty string.";
    }
    {
      assertion = let
        gnupgHome = get ["security" "sops" "gnupgHome"] null;
      in
        gnupgHome == null || (builtins.isString gnupgHome && gnupgHome != "");
      message = "security.sops.gnupgHome must be null or a non-empty string.";
    }
    {
      assertion = let
        gnupgPublicKey = get ["security" "sops" "gnupgPublicKey"] null;
      in
        gnupgPublicKey == null
        || (builtins.isString gnupgPublicKey && gnupgPublicKey != "")
        || builtins.isPath gnupgPublicKey;
      message = "security.sops.gnupgPublicKey must be null, a non-empty string, or a path.";
    }
    {
      assertion = let
        administrativeGroup = get ["security" "sops" "administrativeGroup"] null;
      in
        administrativeGroup == null
        || (builtins.isString administrativeGroup && administrativeGroup != "");
      message = "security.sops.administrativeGroup must be null or a non-empty string.";
    }
    {
      assertion = builtins.isBool (get ["security" "yubikey" "enable"] false);
      message = "security.yubikey.enable must be a boolean.";
    }
    {
      assertion = builtins.isBool (get ["security" "sops" "sshKey" "enable"] false);
      message = "security.sops.sshKey.enable must be a boolean.";
    }
    {
      assertion = let
        name = get ["security" "sops" "sshKey" "name"] "ssh_key";
      in
        builtins.isString name && name != "";
      message = "security.sops.sshKey.name must be a non-empty string.";
    }
    {
      assertion = let
        pubName = get ["security" "sops" "sshKey" "pubName"] "ssh_key_pub";
      in
        builtins.isString pubName && pubName != "";
      message = "security.sops.sshKey.pubName must be a non-empty string.";
    }
    {
      assertion = let
        privMode = get ["security" "sops" "sshKey" "privateMode"] "0600";
      in
        builtins.isString privMode && builtins.match "0[0-7]{3}" privMode != null;
      message = "security.sops.sshKey.privateMode must be an octal mode string (e.g. \"0600\").";
    }
    {
      assertion = let
        pubMode = get ["security" "sops" "sshKey" "publicMode"] "0644";
      in
        builtins.isString pubMode && builtins.match "0[0-7]{3}" pubMode != null;
      message = "security.sops.sshKey.publicMode must be an octal mode string (e.g. \"0644\").";
    }
    {
      assertion = let
        enabled = get ["security" "sops" "enable"] true;
        sshKeyEnabled = get ["security" "sops" "sshKey" "enable"] false;
        priv = get ["security" "sops" "sshKey" "name"] "ssh_key";
        pub = get ["security" "sops" "sshKey" "pubName"] "ssh_key_pub";
      in
        !(enabled && sshKeyEnabled && priv == pub);
      message = "security.sops.sshKey.name and pubName must differ.";
    }
    {
      assertion = builtins.isBool (get ["features" "codingTools" "enable"] true);
      message = "features.codingTools.enable must be a boolean.";
    }
    {
      assertion = builtins.isBool (
        get ["features" "codingTools" "editors" "enable"] (get ["features" "codingTools" "enable"] true)
      );
      message = "features.codingTools.editors.enable must be a boolean.";
    }
    {
      assertion = builtins.isBool (
        get ["features" "codingTools" "aiCli" "enable"] (get ["features" "codingTools" "enable"] true)
      );
      message = "features.codingTools.aiCli.enable must be a boolean.";
    }
    {
      assertion = builtins.isBool (
        get ["features" "codingTools" "aiCli" "codex" "enable"] (
          get ["features" "codingTools" "aiCli" "enable"] (get ["features" "codingTools" "enable"] true)
        )
      );
      message = "features.codingTools.aiCli.codex.enable must be a boolean.";
    }
    {
      assertion = let
        dirs = get ["features" "codingTools" "aiCli" "codex" "trustedDirectories"] [];
      in
        builtins.isList dirs && builtins.all (d: builtins.isString d && d != "") dirs;
      message = "features.codingTools.aiCli.codex.trustedDirectories must be a list of non-empty strings.";
    }
    {
      assertion = let
        model = get ["features" "codingTools" "aiCli" "codex" "model"] "gpt-5.5";
      in
        builtins.isString model && model != "";
      message = "features.codingTools.aiCli.codex.model must be a non-empty string.";
    }
    {
      assertion = let
        valid = ["minimal" "low" "medium" "high" "xhigh"];
        effort = get ["features" "codingTools" "aiCli" "codex" "modelReasoningEffort"] "low";
      in
        builtins.elem effort valid;
      message = "features.codingTools.aiCli.codex.modelReasoningEffort must be one of: minimal, low, medium, high, xhigh.";
    }
    {
      assertion = let
        valid = ["none" "minimal" "low" "medium" "high" "xhigh"];
        effort = get ["features" "codingTools" "aiCli" "codex" "planModeReasoningEffort"] "high";
      in
        builtins.elem effort valid;
      message = "features.codingTools.aiCli.codex.planModeReasoningEffort must be one of: none, minimal, low, medium, high, xhigh.";
    }
    {
      assertion = builtins.isBool (
        get ["features" "codingTools" "aiCli" "opencode" "enable"] (
          get ["features" "codingTools" "aiCli" "enable"] (get ["features" "codingTools" "enable"] true)
        )
      );
      message = "features.codingTools.aiCli.opencode.enable must be a boolean.";
    }
    {
      assertion = builtins.isBool (
        get ["features" "codingTools" "aiCli" "gemini" "enable"] (
          get ["features" "codingTools" "aiCli" "enable"] (get ["features" "codingTools" "enable"] true)
        )
      );
      message = "features.codingTools.aiCli.gemini.enable must be a boolean.";
    }
    {
      assertion = builtins.isBool (
        get ["features" "codingTools" "nixTools" "enable"] (get ["features" "codingTools" "enable"] true)
      );
      message = "features.codingTools.nixTools.enable must be a boolean.";
    }
    {
      assertion = builtins.isBool (get ["features" "tailscale" "enable"] true);
      message = "features.tailscale.enable must be a boolean.";
    }
    {
      assertion = let
        exitNode = get ["features" "tailscale" "exitNode"] null;
      in
        exitNode == null || (builtins.isString exitNode && exitNode != "");
      message = "features.tailscale.exitNode must be null or a non-empty string.";
    }
    {
      assertion = builtins.isBool (get ["features" "ssh" "enable"] true);
      message = "features.ssh.enable must be a boolean.";
    }
    {
      assertion = builtins.isBool (get ["features" "ssh" "openFirewall"] true);
      message = "features.ssh.openFirewall must be a boolean.";
    }
    {
      assertion = let
        port = get ["features" "ssh" "port"] 22;
      in
        builtins.isInt port && port > 0 && port <= 65535;
      message = "features.ssh.port must be an integer in 1..65535.";
    }
    {
      assertion = builtins.isBool (get ["features" "ssh" "passwordAuthentication"] true);
      message = "features.ssh.passwordAuthentication must be a boolean.";
    }
    {
      assertion = let
        valid = ["prohibit-password" "without-password" "forced-commands-only" "no"];
        permitRootLogin = get ["features" "ssh" "permitRootLogin"] "prohibit-password";
      in
        builtins.elem permitRootLogin valid;
      message = "features.ssh.permitRootLogin must be one of: prohibit-password, without-password, forced-commands-only, no (never \"yes\").";
    }
    {
      assertion = let
        keys = get ["features" "ssh" "authorizedKeys"] [];
      in
        builtins.isList keys && builtins.all (k: builtins.isString k && k != "") keys;
      message = "features.ssh.authorizedKeys must be a list of non-empty string public keys.";
    }
    {
      # Lockout guard at the schema layer: key-only SSH requires declared keys.
      assertion = let
        sshEnabled = get ["features" "ssh" "enable"] true;
        pwdAuth = get ["features" "ssh" "passwordAuthentication"] true;
        keys = get ["features" "ssh" "authorizedKeys"] [];
      in
        !(sshEnabled && !pwdAuth && keys == []);
      message = "features.ssh.passwordAuthentication = false requires a non-empty features.ssh.authorizedKeys, otherwise the user is locked out of SSH.";
    }
    {
      assertion = let
        agePublicKey = get ["security" "sops" "agePublicKey"] null;
      in
        agePublicKey == null || (builtins.isString agePublicKey && agePublicKey != "");
      message = "security.sops.agePublicKey must be null or a non-empty string (the host's age public key for future per-host .sops.yaml templating).";
    }
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupCommand = hmBackupCommand;
    extraSpecialArgs = {inherit vars inputs combined;};
    sharedModules = lib.optionals (noctaliaHmModule != null) [noctaliaHmModule];
    users.${primaryUser} = {
      imports = [homeModule];
      home.username = lib.mkForce primaryUser;
      home.homeDirectory = lib.mkForce "/home/${primaryUser}";
      xdg.configHome = lib.mkForce "/home/${primaryUser}/.config";
    };
  };
}
