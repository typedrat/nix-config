{
  config,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;

  apple-fonts = pkgs.symlinkJoin {
    name = "apple-fonts";
    paths = with inputs'.apple-fonts.packages; [
      sf-pro
      sf-compact
      sf-arabic
      sf-armenian
      sf-georgian
      sf-hebrew
      sf-mono
      ny
    ];
  };
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
      fonts.appleColorEmoji.enable = true;

      fonts = {
        packages = with pkgs; [
          # Microsoft fonts that get used everywhere:
          corefonts
          vista-fonts
          vista-fonts-chs
          vista-fonts-cht

          # Primary system fonts, stolen from a company with design sense:
          apple-fonts

          # Coding fonts:
          nerd-fonts.symbols-only
          julia-mono
          inputs'.typedrat-fonts.packages.berkeley-mono
          inputs'.typedrat-fonts.packages.berkeley-mono-nerd-font
          inputs'.typedrat-fonts.packages.berkeley-mono-nerd-font-mono

          # Non-English fonts:
          pkgs.opensiddur-hebrew-fonts
          ipaexfont
          mplus-outline-fonts.githubRelease
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
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
          };

          cache32Bit = true;

          # opensiddur-hebrew-fonts ships these as test fonts. Both claim every
          # codepoint, so a fallback search that reaches them draws blanks or
          # placeholder boxes instead of trying a font that has the glyph.
          confPackages = [
            (pkgs.writeTextDir "etc/fonts/conf.d/60-reject-catch-all-fonts.conf" ''
              <?xml version="1.0"?>
              <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
              <fontconfig>
                <selectfont>
                  <rejectfont>
                    <pattern><patelt name="family"><string>Adobe Blank</string></patelt></pattern>
                    <pattern><patelt name="family"><string>LastResort</string></patelt></pattern>
                  </rejectfont>
                </selectfont>
              </fontconfig>
            '')
          ];
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
