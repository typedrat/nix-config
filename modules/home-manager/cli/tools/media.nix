{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.tools.enable) {
    home.packages = with pkgs; [
      chafa
      ffmpeg-full
      imagemagickBig
      # qbittorrent-cli's .NET 2.1 NuGet runtimes crash patchelf until
      # NixOS/nixpkgs#576897 reaches nixos-unstable. Carrying that patch here
      # rebuilds the entire .NET SDK from source, so the CLI waits instead.
      # qbittorrent-cli
      yt-dlp
    ];
  };
}
