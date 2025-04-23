{inputs, ...}: {
  imports = [
    inputs.wayland-pipewire-idle-inhibit.homeModules.default
  ];

  services.wayland-pipewire-idle-inhibit = {
    enable = true;
    systemdTarget = "graphical-session.target";
    settings = {
      verbosity = "INFO";
      media_minimum_duration = 10;
      idle_inhibitor = "wayland";
      node_blacklist = [
        {name = "spotify";}
      ];
    };
  };
}
