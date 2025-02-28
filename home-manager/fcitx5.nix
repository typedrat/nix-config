{pkgs, ...}: {
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-mozc-ut
        fcitx5-gtk
      ];
    };
  };

  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "pseudo,fcitx"
    ];

    exec-once = [
      "fcitx5 -d -r"
      "fcitx5-remote -r"
    ];
  };
}
