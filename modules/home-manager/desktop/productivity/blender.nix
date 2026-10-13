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
  guiCfg = userCfg.gui or {};
  productivityCfg = guiCfg.productivity or {};
  cliCfg = userCfg.cli or {};
  aiCfg = cliCfg.ai or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  mcpEnabled = aiCfg.enable or false;
  blenderSeries = lib.versions.majorMinor pkgs.blender.version;

  # The addon is a read-only store symlink, so the startup check for a newer
  # addon.py on GitHub could only ever produce an update prompt that fails.
  blender = pkgs.symlinkJoin {
    inherit (pkgs.blender) name;
    paths = [pkgs.blender];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/blender --set BLENDERMCP_NO_UPDATE_CHECK 1
    '';
    inherit (pkgs.blender) meta;
  };
in {
  config = modules.mkIf (guiCfg.enable && productivityCfg.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/blender"];
    };

    home.packages =
      [
        (
          if mcpEnabled
          then blender
          else pkgs.blender
        )
      ]
      ++ lib.optional mcpEnabled pkgs.mcp-for-blender;

    # Blender only loads the addon once it is switched on under Edit →
    # Preferences → Add-ons; after that it autostarts its socket server.
    home.file = lib.mkIf mcpEnabled {
      ".config/blender/${blenderSeries}/scripts/addons/mcp_for_blender.py".source = "${pkgs.mcp-for-blender}/share/mcp-for-blender/addon.py";
    };
  };
}
