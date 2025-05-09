{pkgs, ...}: {
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-mozc-ut
        fcitx5-gtk
      ];
    };
  };

  wayland.windowManager.hyprland.settings = {
    windowrulev2 = [
      "pseudo, class:.*fcitx.*"
    ];
  };
}
