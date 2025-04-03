{pkgs, ...}: {
  # KDE cruft to get Dolphin et al working
  home.packages = with pkgs; [
    kdePackages.plasma-workspace
    kdePackages.kio
    kdePackages.kdf
    kdePackages.kio-fuse
    kdePackages.kio-extras
    kdePackages.kio-admin
    kdePackages.qtwayland
    kdePackages.plasma-integration
    kdePackages.kdegraphics-thumbnailers
    kdePackages.breeze-icons
    kdePackages.qtsvg
    kdePackages.kservice
    shared-mime-info
  ];

  xdg.configFile."menus/applications.menu".text = builtins.readFile ./applications.menu;

  wayland.windowManager.hyprland.settings.exec-once = [
    "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init"
  ];
}
