{
  osConfig,
  lib,
  ...
}: {
  imports =
    [
      ./chat
      ./devtools
      ./games
      ./media
      ./productivity
      ./wezterm

      ./chromium.nix
      ./packages.nix
      ./zen-browser.nix
    ]
    # TODO: fix the Hyprland stuff so it's properly hooked into my new config structure
    ++ lib.optionals osConfig.rat.gui.enable [
      ./hyprland
    ];
}
