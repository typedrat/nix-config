{
  inputs,
  pkgs,
  ...
}: {
  catppuccin = {
    enable = true;
    flavor = "frappe";
    accent = "lavender";
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

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";
  };
}
