{
  inputs,
  pkgs,
  osConfig,
  ...
}: {
  catppuccin = {
    enable = true;
    flavor = osConfig.catppuccin.flavor;
    accent = osConfig.catppuccin.accent;

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

    gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";
  };
}
