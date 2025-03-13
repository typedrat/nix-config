{
  inputs,
  pkgs,
  ...
}: let
  pyprland = inputs.pyprland.packages.${pkgs.stdenv.system}.pyprland;
in {
  home.packages = with pkgs; [
    pyprland
    pwvucontrol
  ];

  xdg.configFile."hypr/pyprland.toml".source = (pkgs.formats.toml {}).generate "pyprland.toml" {
    pyprland = {
      plugins = [
        "fetch_client_menu"
        "scratchpads"
      ];
    };

    fetch_client_menu = {
      engine = "rofi";
    };

    scratchpads = {
      spotify = {
        command = "spotify";
        class = "Spotify";

        animation = "fromLeft";
        size = "50% 50%";

        alt_toggle = true;
        hysteresis = 0.75;
        unfocus = "hide";
      };

      pwvucontrol = {
        command = "pwvucontrol";
        class = "com.saivert.pwvucontrol";

        animation = "fromRight";
        size = "1024px 576px";

        alt_toggle = true;
        hysteresis = 0.75;
        unfocus = "hide";
      };
    };
  };

  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "pypr"
    ];

    windowrulev2 = [
      "float, class:[Ss]potify"
      "float, class:ncspot"
      "float, class:com.saivert.pwvucontrol"
    ];

    bind = [
      "$main_mod,b,exec,pypr fetch-client-menu"
    ];
  };
}
