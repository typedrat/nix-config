{pkgs, ...}: {
  wayland.windowManager.hyprland.settings = {
    exec-once = ["$HOME/.local/share/scripts/hyprland-bitwarden-resize.sh"];

    windowrulev2 = ["suppressevent maximize, class:^(firefox)$"];
  };

  xdg.dataFile."scripts/hyprland-bitwarden-resize.sh".source =
    import ./bitwarden-resize-script.nix pkgs;
}
