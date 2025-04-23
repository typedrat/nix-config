{
  inputs,
  pkgs,
  osConfig,
  ...
}: {
  imports = [
    ./steam.nix
  ];

  catppuccin = {
    enable = true;
    inherit (osConfig.catppuccin) flavor;
    inherit (osConfig.catppuccin) accent;

    gtk.icon.enable = true;
    cursors.enable = true;
    waybar.mode = "createLink";
  };

  gtk = {
    enable = true;

    font = {
      package = inputs.apple-fonts.packages.${pkgs.system}.sf-pro;
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
}
