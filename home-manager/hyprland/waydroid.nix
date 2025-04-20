{pkgs, ...}: {
  home.packages = with pkgs; [
    # cage-xtmapper
    wayland-getevent
    (waydroid-helper.overridePythonAttrs (prev: {
      nativeBuildInputs = (prev.nativeBuildInputs or []) ++ [pkgs.gobject-introspection];
    }))
    android-tools
    scrcpy
  ];

  wayland.windowManager.hyprland.settings = {
    windowrulev2 = [
      "float, class:wlroots"
    ];
  };
}
