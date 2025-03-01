{pkgs, ...}: {
  home.packages = with pkgs; [
    kdePackages.xwaylandvideobridge
  ];

  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "xwaylandvideobridge"
    ];

    windowrulev2 = [
      "opacity 0.0 override, class:^(xwaylandvideobridge)$"
      "noanim, class:^(xwaylandvideobridge)$"
      "noinitialfocus, class:^(xwaylandvideobridge)$"
      "maxsize 1 1, class:^(xwaylandvideobridge)$"
      "noblur, class:^(xwaylandvideobridge)$"
      "nofocus, class:^(xwaylandvideobridge)$"
    ];
  };
}
