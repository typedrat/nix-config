{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;

  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    home.packages = [
      (
        pkgs.discord.override
        {
          withOpenASAR = true;
          withVencord = true;
          # Krisp noise cancellation via upstream patcher (NixOS/nixpkgs#506089).
          # Auto-enabled by withVencord, but set explicitly for clarity.
          withKrisp = true;
          # --ozone-platform=x11: nvidia open kernel modules + Electron + Wayland GBM
          # is broken on this setup (RGBA_8888 buffer allocation fails, GPU process
          # crashes). Force X11 like we do for chromium. Same root cause as the Qt
          # WebEngine workaround in nvidia.nix (NixOS/nixpkgs#508998).
          #
          # --password-store=gnome-libsecret: skip Chromium's broken KWallet
          # autodetection. On KDE Plasma 6, Chromium tries to start kwalletd via
          # org.kde.KLauncher (a KF5 service that no longer exists), times out, and
          # produces ~25s of slow startup before giving up. We have gnome-keyring
          # running with org.freedesktop.secrets, so go straight there. ksecretd
          # also bridges Secret Service to KWallet, so the credentials still end up
          # in the same place.
          commandLineArgs = "--ozone-platform=x11 --password-store=gnome-libsecret";
        }
      )
    ];

    # Discord theming:
    xdg.configFile."Vesktop/settings/quickCss.css".source = ./quickCss.css;

    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/discord" ".config/Vesktop" ".config/Vencord"];
    };
  };
}
