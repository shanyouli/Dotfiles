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
  cfg = cfp.cmus;
in {
  options.modules.media.music.cmus = {
    enable = mkEnableOption "Whether to use cmus";
  };
  config = mkIf cfg.enable {
    user.packages = [pkgs.cmus];
  };
}