{
  pkgs,
  lib,
  config,
  options,
  ...
}:
with lib;
with lib.my; let
  cfp = config.modules.download;
  cfg = cfp.video;
  # bbdown = let
  #   cmd = pkgs.writeScript "bbdown" ''
  #     #!${pkgs.stdenv.shell}
  #       _dir=${config.home.cacheDir}/bbdown
  #       [[ -d $_dir ]] || mkdir -p $_dir
  #       get_shasum() { shasum $1 | cut -d" " -f1 ; }
  #       copy_source() {
  #         local file1=$_dir/bbdown
  #         local file2=${pkgs.bbdown}/lib/BBDown/BBDown
  #         local hash2=$(get_shasum $file2)
  #         [[ -f $file1 ]] && [[ $(get_shasum $file1) == $hash2 ]] || cp -r $file2 $file1
  #       }
  #       copy_source
  #       exec -a "$0" "$_dir/bbdown"  "$@"
  #   '';
  # in
  #   pkgs.runCommandLocal "bbdown" {nativeBuildInputs = [pkgs.makeWrapper];} ''
  #     mkdir -p $out/bin
  #     makeWrapper ${cmd} $out/bin/bbdown \
  #       --set PATH  "${pkgs.ffmpeg}/bin" \
  #       --set LD_LIBRARY_PATH  "${pkgs.icu}/lib"
  #   '';
in {
  options.modules.download.video = {
    enable = mkBoolOpt cfp.enable;
  };
  config = mkIf cfg.enable {
    user.packages = [
      pkgs.unstable.yt-dlp
      # pkgs.unstable.yutto # 使用 pipx 安装
      # pkgs.unstable.bbdown # 使用 yutto 取代
      pkgs.unstable.lux
      pkgs.unstable.fav
    ]; # yutto 下载bilibili
    home.configFile."yt-dlp/config".text = ''
      # 下载默认保存目录
      --paths $HOME/Downloads/Youtube
      # 下载保存文件名
      --output %(title)s.%(id)s.%(ext)s
      # download livestreams from the start.
      --live-from-start
      # 合并后的文件格式
      --merge-output-format mp4
      --proxy http://127.0.0.1:10801
      # 拦截所有广告
      --sponsorblock-remove all
      # 字幕格式为 srt, ass
      --sub-format srt/ass/best
      # Get English and zh 字幕
      --sub-lang en,zh-*,-live_chat
      # 字幕嵌入视频,
      # --embed-subs null
      --downloader dash,m3u8:native
      ${optionalString cfp.aria2.enable ''
        --downloader aria2c
        --downloader-args "aria2c:-x16 -s 8 -k 5M"
      ''}
    '';
    # TODO: alias
  };
}