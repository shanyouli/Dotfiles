{
  pkgs,
  lib,
  config,
  options,
  ...
}:
with lib;
with lib.my; let
  cfp = config.modules.media.music;
  cfg = cfp.mpd;
  tui_list = ["ncmpcpp" "rmpc"];
  mpd_dir = "${config.home.cacheDir}/mpd";
in {
  options.modules.media.music.mpd = {
    enable = mkEnableOption "Whether to use mpd";
    port = mkOpt' types.number 6600 "Listen on port";
    config = mkOpt' types.lines "" "Extra directives added to the end of MPD's configuration file.";
    default = mkOption {
      type = types.str;
      default = "";
      apply = s:
        if builtins.elem s tui_list
        then s
        else "";
      description = "Default tui mpd manager";
    };
    service.enable = mkOpt' types.bool cfg.enable "是否配置 mpd 服务";
    service.startup = mkOpt' types.bool true "mpd 服务是否开机自启动";
  };
  config = mkIf cfg.enable {
    user.packages = with pkgs; [pkgs.mpd pkgs.mpc-cli];

    home.configFile."mpd/mpd.conf".text = ''
      music_directory "${cfp.directory}"
      playlist_directory "${mpd_dir}/playlists"
      db_file "${mpd_dir}/mpd.db"
      log_file "${mpd_dir}/mpd.log"
      pid_file "${mpd_dir}/mpd.pid"
      state_file "${mpd_dir}/mpdstate"
      bind_to_address "127.0.0.1"
      port "${toString cfg.port}"
      auto_update "yes"
      auto_update_depth "2"
      follow_outside_symlinks "yes"
      follow_inside_symlinks "yes"
      decoder {
        plugin "mp4ff"
        enabled "no"
      }
      # Save the macos and Linux conflict part configuration
      ${cfg.config}
    '';

    modules.media.music.mpd.rmpc.enable = mkDefault (cfg.default == "rmpc");
    modules.media.music.mpd.ncmpcpp.enable = mkDefault (cfg.default == "ncmpcpp");

    modules.shell.aliases.mpcs = "mpc search any";
    modules.shell.aliases.mpcsp = "mpc searchplay any";
  };
}