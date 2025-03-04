{
  inputs,
  pkgs,
  ...
}: {
  catppuccin = {
    flavor = "frappe";
    accent = "lavender";

    tty.enable = true;
    grub.enable = true;
    plymouth.enable = true;

    sddm = {
      enable = true;

      font = "SF Pro Display";
      fontSize = "13";
    };
  };

  fonts = {
    packages = with pkgs; [
      corefonts
      vistafonts
      vistafonts-chs
      vistafonts-cht

      google-fonts

      nerd-fonts.symbols-only
      julia-mono
      inputs.typedrat-fonts.packages.${pkgs.system}.berkeley-mono
      inputs.typedrat-fonts.packages.${pkgs.system}.berkeley-mono-nerd-font
      inputs.typedrat-fonts.packages.${pkgs.system}.berkeley-mono-nerd-font-mono

      inputs.apple-fonts.packages.${pkgs.system}.sf-pro
      inputs.apple-fonts.packages.${pkgs.system}.sf-compact
      inputs.apple-fonts.packages.${pkgs.system}.sf-arabic
      inputs.apple-fonts.packages.${pkgs.system}.sf-armenian
      inputs.apple-fonts.packages.${pkgs.system}.sf-georgian
      inputs.apple-fonts.packages.${pkgs.system}.sf-hebrew
      inputs.apple-fonts.packages.${pkgs.system}.sf-mono
      inputs.apple-fonts.packages.${pkgs.system}.ny
      nur.repos.nykma.font-apple-color-emoji

      opensiddur-hebrew-fonts

      ipaexfont
      mplus-outline-fonts.githubRelease
    ];

    fontconfig = {
      subpixel = {
        rgba = "rgb";
      };

      defaultFonts = {
        sansSerif = [
          "SF Pro Display"
          "SF Arabic"
          "SF Armenian"
          "SF Georgian"
          "SF Hebrew"
          "M PLUS 1"
          "Symbols Nerd Font"
        ];

        serif = [
          "New York"
          "Taamey Frank CLM"
          "IPAexMincho"
          "Symbols Nerd Font"
        ];

        monospace = [
          "TX-02"
          "Miriam Mono CLM"
          "M PLUS 1 Code"
          "JuliaMono"
          "Symbols Nerd Font"
        ];

        emoji = [
          "Apple Color Emoji"
        ];
      };

      cache32Bit = true;
    };
  };
}
