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
  classicMacCfg = gamingCfg.classicMac or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # The macemu tree carries only a macOS .icns, so the artwork the Linux builds
  # use lives in the AppImage builder rather than anywhere nixpkgs fetches.
  basiliskiiIcon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Korkman/macemu-appimage-builder/6cbc27c8be39709e71447e7051c9dfcc213dfe40/docker/build/BasiliskII.png";
    hash = "sha256-Mq3d2/oZOpKHB4F0niQFRh0DojI3E7fSnTauMlQYSR8=";
  };
in {
  config = modules.mkIf (guiCfg.enable && classicMacCfg.enable) {
    home.packages = [
      # 68k, for System 7 through Mac OS 8.1
      pkgs.basiliskii
      # PowerPC, for Mac OS 8.5 through 9.0.4
      pkgs.sheepshaver-bin
    ];

    # sheepshaver-bin installs the entry bundled in its AppImage; nixpkgs builds
    # BasiliskII as a bare binary, so reproduce the launcher entry upstream
    # generates for it, actions and all.
    xdg.dataFile."icons/hicolor/256x256/apps/BasiliskII.png".source = basiliskiiIcon;

    xdg.desktopEntries.BasiliskII = {
      name = "BasiliskII";
      genericName = "68k Macintosh Emulator";
      comment = "Open source classic 68k Mac OS emulator";
      exec = "BasiliskII";
      icon = "BasiliskII";
      categories = ["Emulator" "System"];
      terminal = false;
      type = "Application";
      startupNotify = false;
      actions = {
        skip-settings = {
          name = "Start BasiliskII (skip settings)";
          exec = "BasiliskII --nogui true";
        };
        force-settings = {
          name = "Start BasiliskII (force settings)";
          exec = "BasiliskII --nogui false";
        };
        opengl = {
          name = "Start BasiliskII (opengl)";
          exec = "BasiliskII --sdlrender opengl";
        };
      };
    };

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        # Emulator settings and the emulated Macs' NVRAM
        ".config/BasiliskII"
        ".config/SheepShaver"
      ];
    };
  };
}
