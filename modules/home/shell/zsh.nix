{
  config,
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  zshEnabled = get [ "features" "shell" "zsh" "enable" ] false;
  starshipEnabled = get [ "features" "shell" "starship" "enable" ] true;

  # Upstream Rose Pine Starship preset (MIT).
  # https://github.com/rose-pine/starship
  rosePineStarship = pkgs.fetchFromGitHub {
    owner = "rose-pine";
    repo = "starship";
    rev = "ce244cb048e19ef6207936c3087141c8a796bca5";
    hash = "sha256-oFHyel6nYOPdK9VbNp7KbKL/3WeBp/SFHzKTq/9Bhh8=";
  };
  rosePineStarshipSettings = builtins.fromTOML (
    builtins.readFile "${rosePineStarship}/rose-pine.toml"
  );
  # Stylix would overwrite the upstream preset; skip it when Stylix is active.
  # When Stylix is inactive its HM module may not be imported, so this
  # definition must be omitted entirely (see modules/theme/stylix-enabled.nix).
  stylixActive = (import ../../theme/stylix-enabled.nix { inherit lib vars; }).enable;
in
{
  # The stylix key must be structurally absent when Stylix is inactive:
  # option paths are rejected even under `mkIf false`, and without Stylix
  # its HM module may not be imported at all. optionalAttrs forces
  # stylixActive while constructing this module's config.
  config =
    if !zshEnabled then
      { }
    else
      {
        programs = {
          zsh = {
            enable = true;
            dotDir = "${config.xdg.configHome}/zsh";
            enableCompletion = true;
            autocd = true;
            defaultKeymap = "emacs";

            autosuggestion = {
              enable = true;
              strategy = [
                "history"
                "completion"
              ];
            };

            syntaxHighlighting.enable = true;
            historySubstringSearch.enable = true;

            history = {
              size = 100000;
              save = 100000;
              share = true;
              ignoreAllDups = true;
              extended = true;
            };

            zsh-abbr = {
              enable = true;
              abbreviations = {
                gst = "git status";
                gco = "git checkout";
                gpl = "git pull";
              };
            };

            shellAliases = {
              ll = "ls -lah";
              ".." = "cd ..";
              "..." = "cd ../..";
            };
          };

          starship = {
            enable = starshipEnabled;
            enableZshIntegration = starshipEnabled;
            settings = rosePineStarshipSettings;
          };
        };
      }
      // lib.optionalAttrs stylixActive {
        # Stylix would overwrite the upstream preset; skip it when active.
        stylix.targets.starship.enable = false;
      };
}
