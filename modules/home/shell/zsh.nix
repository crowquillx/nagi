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
  rosePineStarshipPreset = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/rose-pine/starship/0edc3c781f219565453bbb8e8e7af56ebc2a0d8a/rose-pine.toml";
    hash = "sha256-0nK3gRQDuoH+jAvKWbM04rVUXtFNRgvB86jKhuvnr9g=";
  };
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
        settings = builtins.fromTOML (builtins.readFile rosePineStarshipPreset);
      };
    };
  };
}
