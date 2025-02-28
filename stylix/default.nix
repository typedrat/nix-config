{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [
    corefonts
    vistafonts
    vistafonts-chs
    vistafonts-cht
    google-fonts

    nerd-fonts.symbols-only
    julia-mono
    nur.repos.nykma.font-apple-color-emoji
    inputs.apple-fonts.packages.${pkgs.system}.sf-pro
    inputs.apple-fonts.packages.${pkgs.system}.sf-mono
    inputs.apple-fonts.packages.${pkgs.system}.ny
    inputs.typedrat-fonts
    opensiddur-hebrew-fonts
  ];

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-frappe.yaml";

    image = ./shamimomo.jpg;
    polarity = "dark";

    fonts = {
      sansSerif = {
        package = inputs.apple-fonts.packages.${pkgs.system}.sf-pro;
        name = "SF Pro Display";
      };

      serif = {
        package = inputs.apple-fonts.packages.${pkgs.system}.ny;
        name = "New York";
      };

      monospace = {
        package = inputs.typedrat-fonts.packages.${pkgs.system}.berkeley-mono;
        name = "TX-02";
      };

      emoji = {
        package = pkgs.nur.repos.nykma.font-apple-color-emoji;
        name = "Apple Color Emoji";
      };

      sizes = {
        applications = 13;
        desktop = 13;
        popups = 11;
        terminal = 14;
      };
    };

    cursor = {
      package = pkgs.catppuccin-cursors;
      name = "frappeLavender";
    };

    opacity = {
      terminal = 0.9;
    };
  };
}
