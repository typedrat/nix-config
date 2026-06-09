{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types genAttrs optional;
  cfg = config.rat.gaming.sunshine;
in {
  options.rat.gaming.sunshine = {
    enable = mkEnableOption "Sunshine game streaming host";

    users = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["awilliams"];
      description = ''
        Users permitted to use Sunshine. Each listed user is added to the
        `uinput` group (so Moonlight clients can inject gamepad, keyboard, and
        mouse input via /dev/uinput) and the `sunshine` group (so they can read
        the credentials_file).
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the LAN firewall ports Sunshine/Moonlight require.";
    };
  };

  config = mkIf (config.rat.gaming.enable && cfg.enable) {
    # Dedicated group for credential-file access (distinct from uinput, even
    # though the user set overlaps today — credential access != input access).
    users.groups.sunshine = {};

    # Grant each permitted user uinput access (input injection) and sunshine
    # group membership (credentials_file read).
    users.users = genAttrs cfg.users (_: {
      extraGroups = ["uinput" "sunshine"];
    });

    # Non-fatal guard: Sunshine still streams video without input injection,
    # but Moonlight gamepad/keyboard/mouse will silently fail.
    warnings = optional (cfg.users == []) ''
      rat.gaming.sunshine is enabled but `users` is empty. No user has been
      added to the `uinput`/`sunshine` groups, so Moonlight input injection
      and credential-file access will not work. Set
      `rat.gaming.sunshine.users = [ "<username>" ];`.
    '';
  };
}
