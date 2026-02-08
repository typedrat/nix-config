# Wrapper module for flakehub-deploy that adds SOPS and impermanence integration
{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
  cfg = config.rat.deployment;
  impermanenceCfg = config.rat.impermanence;
  stateDir = "/var/lib/flakehub-deploy";
in {
  imports = [inputs.flakehub-deploy.nixosModules.default];

  options.rat.deployment = {
    enable = mkEnableOption "FlakeHub GitOps deployment";

    flakeRef = mkOption {
      type = types.str;
      example = "typedrat/nix-config/0.1";
      description = "FlakeHub flake reference (org/repo/version-pattern).";
    };

    configuration = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "NixOS configuration name to deploy. Defaults to the hostname.";
    };

    operation = mkOption {
      type = types.enum ["switch" "boot"];
      default = "switch";
      description = ''
        The nixos-rebuild operation to perform.
        - switch: Apply changes immediately
        - boot: Apply changes on next reboot (safer for workstations)
      '';
    };

    polling = {
      enable = mkEnableOption "fallback polling for deployments";

      interval = mkOption {
        type = types.str;
        default = "15m";
        description = "Polling interval for checking new versions.";
      };
    };

    rollback = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically rollback to previous generation on deployment failure.";
      };
    };

    webhook = {
      enable = mkEnableOption "webhook listener for GitHub deployments";

      subdomain = mkOption {
        type = types.str;
        default = "${config.networking.hostName}-webhook";
        description = "Subdomain for the webhook endpoint (used with Traefik).";
      };
    };

    tunnel = {
      enable = mkEnableOption "Cloudflare Tunnel for webhook access";
    };
  };

  config = mkMerge [
    # Map rat.deployment to services.flakehub-deploy
    (mkIf cfg.enable {
      services.flakehub-deploy = {
        enable = true;
        inherit (cfg) flakeRef configuration operation;

        polling = {
          inherit (cfg.polling) enable interval;
        };

        rollback = {
          inherit (cfg.rollback) enable;
        };

        notification.discord.webhookUrlFile =
          config.sops.secrets."deploy/notification/discordWebhook".path;
      };

      # SOPS secrets for deployment
      sops.secrets."deploy/notification/discordWebhook" = {
        sopsFile = ../../../../secrets/deploy.yaml;
        key = "notification/discordWebhook";
      };
    })

    # Webhook configuration
    (mkIf (cfg.enable && cfg.webhook.enable) {
      services.flakehub-deploy.webhook = {
        enable = true;
        inherit (config.links.flakehub-webhook) port;
        secretFile = config.sops.secrets."deploy/webhookSecret".path;
      };

      # SOPS secret for webhook validation
      sops.secrets."deploy/webhookSecret" = {
        sopsFile = ../../../../secrets/deploy.yaml;
        key = "webhookSecret";
        restartUnits = ["flakehub-webhook-handler.service"];
      };

      # Port magic link for the webhook service
      # Use fixed port 9876 when tunnel is enabled (must match Terraform config)
      links.flakehub-webhook = {
        protocol = "http";
        port = lib.mkIf cfg.tunnel.enable 9876;
      };
    })

    # Traefik route for webhook (when not using tunnel)
    (mkIf (cfg.enable && cfg.webhook.enable && !cfg.tunnel.enable) {
      rat.services.traefik.routes.flakehub-webhook = {
        enable = true;
        inherit (cfg.webhook) subdomain;
        serviceUrl = config.links.flakehub-webhook.url;
        authentik = false; # GitHub needs direct access
      };
    })

    # Cloudflare tunnel configuration
    (mkIf (cfg.enable && cfg.tunnel.enable) {
      services.flakehub-deploy.tunnel = {
        enable = true;
        environmentFile = config.sops.templates."cloudflared-tunnel-deploy.env".path;
      };

      # SOPS secret for tunnel token
      sops.secrets."deploy/cloudflare/tunnelToken" = {
        sopsFile = ../../../../secrets/deploy.yaml;
        key = "cloudflare/tunnelToken";
      };

      # Template to create environment file from raw token
      sops.templates."cloudflared-tunnel-deploy.env" = {
        content = ''
          TUNNEL_TOKEN=${config.sops.placeholder."deploy/cloudflare/tunnelToken"}
        '';
        restartUnits = ["cloudflared-tunnel-deploy.service"];
      };
    })

    # Impermanence integration
    (mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = stateDir;
          user = "root";
          group = "root";
          mode = "0700";
        }
      ];
    })
  ];
}
