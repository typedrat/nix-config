{
  config,
  lib,
  ...
}: let
  inherit (lib) types;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.rat.networking.tailscale;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.networking.tailscale = {
    enable = mkEnableOption "Tailscale";

    operator = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        User allowed to drive tailscaled without root. The tray app needs
        this to connect, disconnect, or switch exit nodes.
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.tailscale = {
        enable = true;
        # Direct WireGuard connections need the listen port reachable;
        # without it every peer falls back to DERP relays.
        openFirewall = true;
        # Loosens reverse-path filtering so traffic from subnet routes and
        # exit nodes isn't dropped as spoofed.
        useRoutingFeatures = "client";
        extraSetFlags = lib.optional (cfg.operator != null) "--operator=${cfg.operator}";
      };
    })
    (mkIf (cfg.enable && impermanenceCfg.enable) {
      # Node key and login state; losing it re-registers the machine as a
      # new device on every boot.
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        "/var/lib/tailscale"
      ];
    })
  ];
}
