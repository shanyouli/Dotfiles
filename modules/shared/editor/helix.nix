{
  pkgs,
  lib,
  config,
  options,
  ...
}:
with lib;
with lib.my; let
  cfm = config.modules;
  cfg = cfm.editor.helix;
  tomlFormat = pkgs.formats.toml {};
in {
  options.modules.editor.helix = {
    enable = mkEnableOption "Whether to use helix";

    package = mkOpt' types.package pkgs.helix "The package to use for helix.";
    extraPackages = mkOpt' (with types; listOf package) [] "Extra packages available to hx.";

    settings = mkOpt' tomlFormat.type {} "Configuration written to {file}~/.config/helixconfig.toml.";
    languages = with types;
      mkOpt' (coercedTo (listOf tomlFormat.type) (language:
        lib.warn ''
          The syntax of modules.editor.helix.languages has changed.
          It now generates the whole languages.toml file instead of just the language array in that file.

          Use `modules.editor.helix.languages = { language = <languages list>; }` instead.
        '' {inherit language;}) (addCheck tomlFormat.type builtins.isAttrs)) {} "lsp support";
    ignores = with types; mkOpt' (listOf str) [] "ignores .gitignore files.";
    themes = mkOpt' (types.attrsOf tomlFormat.type) {} "Each theme is written to ~/.config/helix/themes/xx.toml";
  };
  config = mkIf cfg.enable {
    user.packages =
      if cfg.extraPackages != []
      then [
        (pkgs.symlinkJoin {
          name = "${getName cfg.package}-wrapped-${getVersion cfg.package}";
          paths = [cfg.package];
          preferLocalBuild = true;
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/hx --prefix PATH : ${makeBinPath cfg.extraPackages}"
          '';
        })
      ]
      else [cfg.package];

    home.configFile = let
      settings = {
        "helix/config.toml" = mkIf (cfg.settings != {}) {
          source = tomlFormat.generate "helix-config" cfg.settings;
        };
        "helix/languages.toml" = mkIf (cfg.languages != {}) {
          source = tomlFormat.generate "helix-languages-config" cfg.languages;
        };
        "helix/ignore" = mkIf (cfg.ignores != []) {
          text = concatStringsSep "\n" cfg.ignores + "\n";
        };
      };
      themes = mapAttrs' (n: v:
        nameValuePair "helix/themes/${n}.toml" {
          source = tomlFormat.generate "helix-theme-${n}" v;
        })
      cfg.themes;
    in
      settings // themes;
  };
}
