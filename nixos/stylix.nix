{
  inputs,
  outputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [
    (nerdfonts.override {
      fonts = ["NerdFontsSymbolsOnly"];
    })
    julia-mono
    nur.repos.nykma.font-apple-color-emoji
    inputs.apple-fonts.packages.${pkgs.system}.sf-pro
    inputs.apple-fonts.packages.${pkgs.system}.sf-mono
    inputs.apple-fonts.packages.${pkgs.system}.ny
    inputs.typedrat-fonts
  ];

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-storm.yaml";

    image = pkgs.fetchurl {
      url = "https://cdn.donmai.us/original/16/a4/__yoshida_yuuko_and_chiyoda_momo_machikado_mazoku_drawn_by_akuruhi0__16a4e95a8eaa099f14be1de96e722cc7.jpg";
      hash = "sha256-CeD2/22GqoDOBLp9lhZNNR//EfQCMQeJpCvbCU1pCAQ=";
    };

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
  };
}
