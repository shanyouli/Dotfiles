# 常用压缩、解压工具, unzip/zip unrar/rar , p7zip.
#  gnutar.
{
  pkgs,
  lib,
  config,
  options,
  ...
}:
with lib;
with lib.my; let
  cfp = config.modules.archive;
  cfg = cfp.common;
in {
  options.modules.archive.common = {
    enable = mkEnableOption "Whether to use archive";
  };
  config = mkIf cfg.enable {
    user.packages = with pkgs; [p7zip zip unzip rar unrar];
  };
}