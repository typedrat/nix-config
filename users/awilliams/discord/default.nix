{pkgs, ...}: {
  home.packages = [
    (
      pkgs.discord.override
      {
        withOpenASAR = true;
        withVencord = true;
      }
    )
  ];

  # Discord theming:
  xdg.configFile."Vesktop/settings/quickCss.css".source = ./quickCss.css;
}
