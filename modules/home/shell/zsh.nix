{
  config,
  lib,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  zshEnabled = get [ "features" "shell" "zsh" "enable" ] false;
  starshipEnabled = get [ "features" "shell" "starship" "enable" ] true;
  rosePineStarshipSettings = builtins.fromTOML (builtins.readFile ./starship/rose-pine.toml);
in
{
  config = lib.mkIf zshEnabled {
    stylix.targets.starship.enable = false;

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
  };
}
