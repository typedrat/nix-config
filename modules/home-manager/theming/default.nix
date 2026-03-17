{
  config,
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  themingCfg = userCfg.theming or {};
  guiCfg = userCfg.gui or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  capitalizeFirst = str:
    (lib.toUpper (builtins.substring 0 1 str))
    + (builtins.substring 1 (builtins.stringLength str) str);
in {
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    inputs.plasma-manager.homeModules.plasma-manager

    ./steam.nix
  ];

  config = modules.mkIf themingCfg.enable (modules.mkMerge [
    {
      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        directories = [".config/dconf"];
      };

      catppuccin = {
        enable = true;
        inherit (osConfig.catppuccin) flavor;
        inherit (osConfig.catppuccin) accent;
      };
    }

    (modules.mkIf guiCfg.enable {
      catppuccin = {
        gtk.icon.enable = true;
        cursors.enable = true;
        kvantum.enable = true;
        waybar.mode = "createLink";
      };

      gtk = {
        enable = true;

        font = {
          name = "SF Pro Display";
          size = 13;
        };

        theme = {
          package = pkgs.adw-gtk3;
          name = "adw-gtk3-dark";
        };

        gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
        gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
        gtk3.extraCss = builtins.readFile ./gtk3/gtk.css;
        gtk4.extraCss = builtins.readFile ./gtk4/gtk.css;
      };

      xdg.configFile."gtk-4.0/colors.css".source = ./gtk4/colors.css;

      dconf = {
        enable = true;
        settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
          };

          "org/gnome/desktop/wm/preferences" = {
            button-layout = "";
          };
        };
      };

      qt = {
        enable = true;
        platformTheme.name = "kvantum";
        style.name = "kvantum";
      };

      # KDE color scheme via plasma-manager (replaces kde-colors.nix + kdeglobals.nix)
      programs.plasma.workspace.colorScheme = "Catppuccin${capitalizeFirst config.catppuccin.flavor}${capitalizeFirst config.catppuccin.accent}";

      home.packages = [
        (pkgs.catppuccin-kde.override {
          flavour = [config.catppuccin.flavor];
          accents = [config.catppuccin.accent];
          winDecStyles = ["modern"];
        })
      ];
    })
  ]);
}
