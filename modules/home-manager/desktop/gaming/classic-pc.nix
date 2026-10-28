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
  gamingCfg = guiCfg.gaming or {};
  classicPCCfg = gamingCfg.classicPC or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  tankRoot =
    if impermanenceCfg.tank.enable
    then impermanenceCfg.tankDir
    else persistDir;

  # The sound samples for floppy and hard disk audio ship in a separate asset
  # pack, which 86Box looks for in share/86Box/assets alongside the ROMs.
  # Fetched by tag, so the hash is only right for one release: a stale hash
  # would silently reuse the old pack rather than fail.
  _86box = let
    base = pkgs._86box.override {
      unfreeEnableDiscord = true;
      unfreeEnableRoms = true;
    };
  in
    assert lib.assertMsg (base.version == "6.0")
    "86box is now ${base.version}; update the asset pack tag hash in classic-pc.nix";
      base.overrideAttrs (old: {
        postInstall =
          old.postInstall
          + ''
            ln -s ${pkgs.fetchFromGitHub {
              owner = "86Box";
              repo = "assets";
              tag = "v${old.version}";
              hash = "sha256-7Fl0o48HT6XAYVQEsGUG6TbJlHFHLIKn7OcOrhkeGI8=";
            }} $out/share/86Box/assets
          '';
      });
in {
  config = modules.mkIf (guiCfg.enable && classicPCCfg.enable) {
    home.packages = [
      # The ROMs and assets land under share/86Box, which 86Box finds through
      # XDG_DATA_DIRS, so a persisted $XDG_DATA_HOME/86Box doesn't shadow them.
      _86box
    ];

    home.persistence = modules.mkIf impermanenceCfg.home.enable (modules.mkMerge [
      {
        # 86box_global.cfg and the VM manager's settings
        ${persistDir}.directories = [".config/86Box"];
      }
      {
        # "Virtual Machines", whose hard disk images get large
        ${tankRoot}.directories = [".local/share/86Box"];
      }
    ]);
  };
}
