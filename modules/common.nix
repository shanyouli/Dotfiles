{
  config,
  options,
  lib,
  pkgs,
  inputs,
  home-manager,
  ...
}:
with lib;
with lib.my; let
  name = lib.var.user;
  homedir = lib.var.homedir;
in {
  options = with types; {
    # user = mkOpt attrs {};
    user = mkOption {type = options.users.users.type.functor.wrapped;};
    home = {
      file = mkOpt' attrs {} "Files to place directly in $HOME";
      configFile = mkOpt' attrs {} "Files to place directly in $XDG_CONFIG_HOME";
      dataFile = mkOpt' attrs {} "Files to place in $XDG_CONFIG_HOME";
      packages = mkOpt' (listOf package) [] "home-manager packages alias";
      programs = mkOpt' attrs {} "home-manager programs";
      profileBinDir = mkOpt' path "${homedir}/.nix-profile/bin" "home-manager profile-directory bin";
      activation = mkOpt' attrs {} "home-manager activation script";
      services = mkOpt' attrs {} "home-manager services";

      dataDir = mkOpt' path "${homedir}/.local/share" "xdg_data_home";
      stateDir = mkOpt' path "${homedir}/.local/state" "xdg_state_home";
      binDir = mkOpt' path "${homedir}/.local/bin" "xdg_bin_home";
      configDir = mkOpt' path "${homedir}/.config" "xdg_config_home";
      cacheDir = mkOpt' path "${homedir}/.cache" "xdg_cache_home";

      profileDirectory = mkOpt' path "" "";

      actionscript = mkOpt' lines "" "激活时，执行脚本";
    };
    env = mkOption {
      type = attrsOf (oneOf [str path (listOf (either str path))]);
      apply = mapAttrs (n: v:
        if isList v
        then concatMapStringsSep ":" toString v
        else (toString v));
      default = {};
      description = "Configuring System Environment Variables";
    };
  };
  config = mkMerge [
    {
      user = mkMerge [
        {
          inherit name;
          description = "The primary user account";
          home = homedir;
          uid = mkDefault 1000;
        }
        (mkIf pkgs.stdenvNoCC.isLinux {
          extraGroups = ["wheel"];
          group = "users";
          isNormalUser = true;
        })
      ];
      home.programs.home-manager.enable = true;
      home.profileBinDir = "${config.home-manager.users."${config.user.name}".home.profileDirectory}/bin";

      home.profileDirectory = "${config.home-manager.users."${config.user.name}".home.profileDirectory}";

      home-manager = {
        extraSpecialArgs = {inherit inputs;};
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        users.${config.user.name} = {
          home = {
            file = mkAliasDefinitions options.home.file;
            # Necessary for home-manager to work with flakes, otherwise it will
            # look for a nixpkgs channel.
            stateVersion =
              if pkgs.stdenv.isDarwin
              then "24.05"
              else config.system.stateVersion;
            username = config.user.name;

            activation = mkAliasDefinitions options.home.activation;
            packages = mkAliasDefinitions options.home.packages;
          };
          xdg = {
            enable = true;
            configFile = mkAliasDefinitions options.home.configFile;
            dataFile = mkAliasDefinitions options.home.dataFile;

            dataHome = mkAliasDefinitions options.home.dataDir;
            cacheHome = mkAliasDefinitions options.home.cacheDir;
            configHome = mkAliasDefinitions options.home.configDir;
            stateHome = mkAliasDefinitions options.home.stateDir;
          };
          programs = mkAliasDefinitions options.home.programs;
          services = mkAliasDefinitions options.home.services;
          home.enableNixpkgsReleaseCheck = false;
        };
      };

      users.users.${config.user.name} = mkAliasDefinitions options.user;
      nix.settings = let
        users = ["root" config.user.name "@admin" "@wheel"];
      in {
        trusted-users = users;
        allowed-users = users;
      };

      environment.extraInit = mkOrder 10 (let
        inherit (pkgs.stdenvNoCC) isAarch64 isAarch32 isDarwin;
        darwinPath = optionalString isDarwin (let
          brewHome =
            if isAarch64 || isAarch32
            then "/opt/homebrew/bin"
            else "/usr/local/bin";
          prevPath =
            builtins.replaceStrings ["$USER" "$HOME"] [config.user.name homedir]
            (pkgs.lib.makeBinPath (builtins.filter (x: x != "/nix/var/nix/profiles/default") config.environment.profiles));
        in ''
          PATH=""
          eval $(/usr/libexec/path_helper -s)
          [ -d ${brewHome} ] && eval $(${brewHome}/brew shellenv)
          PATH=${prevPath}''${PATH:+:}$PATH
        '');
      in
        ''
          ${darwinPath}
        ''
        + concatStringsSep "\n" (mapAttrsToList (n: v: (
            if "${n}" == "PATH"
            then ''export ${n}="${v}:''${PATH:+:}$PATH"''
            else ''export ${n}="${v}"''
          ))
          config.env)
        + optionalString (config.nix.envVars != {}) ''
          unset all_proxy http_proxy https_proxy
        '');
    }
    (mkIf config.modules.gui.enable {
      fonts.packages = config.modules.gui.fonts;
    })
    {
      environment = {
        systemPackages = with pkgs; [
          # standard toolset
          coreutils-full
          wget
          git
          jq

          # helpful shell stuff
          bat
          fzf
          (ripgrep.override {withPCRE2 = true;})
          #
          curl
          pkgs.unstable.cached-nix-shell # Better nix-shell
        ];
        etc = {
          home-manager.source = "${inputs.home-manager}";
          nixpkgs-unstable.source = "${inputs.nixpkgs}";
          nixpkgs.source =
            if pkgs.stdenvNoCC.isDarwin
            then "${inputs.darwin-stable}"
            else "${inputs.nixos-stable}";
        };
        # list of acceptable shells in /etc/shells
        shells = with pkgs; [bash zsh];
      };
    }
    (mkIf (config.modules.shell.zsh.enable) {
      programs.zsh = {
        enable = true;
        # 我将自动启用bashcompinit 和compinit配置
        enableCompletion = false;
        enableBashCompletion = false;
        promptInit = "";
      };
    })
    (mkIf (config.modules.shell.default == "zsh") {
      user.shell = pkgs.zsh;
    })
  ];
}