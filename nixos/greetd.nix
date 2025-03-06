{
  pkgs,
  config,
  ...
}: {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = let
          dmcfg = config.services.displayManager;
        in ''
          ${pkgs.greetd.tuigreet}/bin/tuigreet \
            --debug \
            --time \
            --asterisks \
            --remember-session \
            --user-menu \
            --theme 'text=white;container=black;border=magenta;greet=magenta;input=red;action=magenta;button=white' \
            --power-shutdown '/run/current-system/systemd/bin/systemctl poweroff' \
            --power-reboot '/run/current-system/systemd/bin/systemctl reboot' \
            --sessions '${dmcfg.sessionData.desktops}/share/wayland-sessions'
        '';
        user = "greeter";
      };
    };
  };

  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  systemd.tmpfiles.settings.tuigreet."/var/cache/tuigreet".d = {
    user = "greeter";
    group = "greeter";
    mode = "0755";
  };
}
