{
  config,
  osConfig,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  inherit (inputs'.hyprland.packages) hyprland;
  inherit (inputs'.pyprland.packages) pyprland;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};

  cfg = config.programs.pyprland;
in {
  options.programs.pyprland = {
    settings = options.mkOption {
      type = types.attrs;
      default = {};
      description = "Pyprland configuration";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf ((guiCfg.enable or false) && (hyprlandCfg.enable or false)) {
      home.packages = with pkgs; [
        pyprland
        pwvucontrol
      ];

      programs.pyprland.settings = {
        pyprland = {
          hyprland_version = builtins.head (builtins.split "\\+" hyprland.version);
          plugins = [
            "scratchpads"
          ];
        };

        scratchpads = {
          spotify = {
            command = "spotify";
            class = "Spotify";

            animation = "fromLeft";
            size = "50% 50%";

            alt_toggle = true;
            hysteresis = 0.75;
            unfocus = "hide";
          };

          pwvucontrol = {
            command = "pwvucontrol";
            class = "com.saivert.pwvucontrol";
            lazy = true;

            animation = "fromRight";
            size = "1024px 576px";

            alt_toggle = true;
            hysteresis = 0.75;
            unfocus = "hide";
          };
        };
      };

      xdg.configFile."hypr/pyprland.toml".source = (pkgs.formats.toml {}).generate "pyprland.toml" cfg.settings;

      systemd.user.services.pyprland = {
        Unit = {
          Description = "Pyprland";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };

        Service = {
          ExecStart = lib.getExe' pyprland "pypr";
          Restart = "on-failure";
          RestartSec = 5;
        };

        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };

      wayland.windowManager.hyprland.extraConfig = ''
        windowrule {
          name = float-spotify
          match:class = [Ss]potify
          float = on
        }

        windowrule {
          name = float-ncspot
          match:class = ncspot
          float = on
        }

        windowrule {
          name = float-pwvucontrol
          match:class = com.saivert.pwvucontrol
          float = on
        }
      '';
    })

    (modules.mkIf ((guiCfg.enable or false) && (hyprlandCfg.enable or false) && (hyprlandCfg.launcher or "rofi") == "rofi") {
      programs.pyprland.settings = {
        pyprland.plugins = ["fetch_client_menu"];

        fetch_client_menu = {
          engine = "rofi";
        };
      };

      wayland.windowManager.hyprland.settings = {
        bind = [
          "$main_mod,b,exec,pypr fetch-client-menu"
        ];
      };
    })
  ];
}
