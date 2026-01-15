{
  config,
  self',
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
in {
  options.rat.theming.fonts = {
    enable =
      mkEnableOption "fonts"
      // {
        default = config.rat.theming.enable && config.rat.gui.enable;
      };

    enableGoogleFonts = mkEnableOption "the complete Google Fonts collection";
  };

  config = mkIf config.rat.theming.fonts.enable (mkMerge [
    {
      fonts = {
        packages = with pkgs; [
          # Microsoft fonts that get used everywhere:
          corefonts
          vista-fonts
          vista-fonts-chs
          vista-fonts-cht

          # Primary system fonts, stolen from a company with design sense:
          self'.packages.apple-fonts
          inputs'.apple-emoji.packages.apple-emoji-linux

          # Coding fonts:
          nerd-fonts.symbols-only
          julia-mono
          inputs'.typedrat-fonts.packages.berkeley-mono
          inputs'.typedrat-fonts.packages.berkeley-mono-nerd-font
          inputs'.typedrat-fonts.packages.berkeley-mono-nerd-font-mono

          # Non-English fonts:
          self'.packages.opensiddur-hebrew-fonts
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

    (mkIf config.rat.theming.fonts.enableGoogleFonts {
      fonts.packages = [
        pkgs.google-fonts
      ];
    })

    (mkIf (! config.rat.theming.fonts.enableGoogleFonts) {
      fonts.packages = [
        pkgs.noto-fonts
        (pkgs.google-fonts.override {
          fonts = ["DotGothic16"];
        })
      ];
    })
  ]);
}
