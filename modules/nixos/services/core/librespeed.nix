{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.librespeed;
  impermanenceCfg = config.rat.impermanence;

  inherit (config.rat.services) domainName;

  domain = "${cfg.subdomain}.${domainName}";

  lsCfg = config.services.librespeed;

  # Generate frontend assets, replicating upstream module logic with servers.json added.
  librespeedAssets =
    pkgs.runCommand "librespeed-assets" {
      serversList = ''
        function get_servers() {
          return ${builtins.toJSON lsCfg.frontend.servers}
        }
        function override_settings () {
        ${lib.pipe lsCfg.frontend.settings [
          (lib.mapAttrs (name: val: "  s.setParameter(${builtins.toJSON name},${builtins.toJSON val});"))
          lib.attrValues
          lib.concatLines
        ]}
        }
      '';
      serversJson = builtins.toJSON lsCfg.frontend.servers;
      passAsFile = ["serversList" "serversJson"];
    } ''
      cp -r --no-preserve=mode ${lsCfg.package}/assets $out
      cp "$serversListPath" "$out/servers_list.js"
      cp "$serversJsonPath" "$out/servers.json"
      substitute ${lsCfg.package}/assets/index.html $out/index.html \
        --replace-fail "s.setParameter(\"telemetry_level\",\"basic\"); //enable telemetry" "override_settings();" \
        --replace-fail "LibreSpeed Example" ${lib.escapeShellArg (lib.escapeXML lsCfg.frontend.pageTitle)} \
        --replace-fail "PUT@YOUR_EMAIL.HERE" ${lib.escapeShellArg (lib.escapeXML lsCfg.frontend.contactEmail)} \
        --replace-fail "TO BE FILLED BY DEVELOPER" ${lib.escapeShellArg (lib.escapeXML lsCfg.frontend.contactEmail)}
    '';
in {
  options.rat.services.librespeed = {
    enable = options.mkEnableOption "LibreSpeed";
    subdomain = options.mkOption {
      type = types.str;
      default = "speed";
      description = "The subdomain for LibreSpeed.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links = {
        librespeed = {
          protocol = "http";
        };
        librespeed-backend = {
          protocol = "http";
        };
      };

      services.librespeed = {
        enable = true;

        frontend = {
          enable = true;
          contactEmail = "admin@${domainName}";
          pageTitle = "LibreSpeed";
          useNginx = false;

          servers = [
            {
              name = domain;
              server = "//${domain}";
            }
          ];
        };

        settings = {
          bind_address = "127.0.0.1";
          listen_port = config.links.librespeed-backend.port;
          base_url = "backend";
          # Static assets are served by lighttpd, not by librespeed-rust.
          assets_path = pkgs.writeTextDir "index.html" "";
          # SQLite for telemetry / result image generation. librespeed-rust's
          # postgres/mysql code paths require TCP with hostname+name+username+
          # password (no unix-socket peer auth), which isn't worth the setup
          # for a speed test results table. The DB lives under StateDirectory.
          database_type = "sqlite";
          database_file = "/var/lib/librespeed/speedtest.sqlite";
        };
      };

      # Serve static frontend assets via lighttpd (shared instance with theme-park).
      services.lighttpd.extraConfig = ''
        $SERVER["socket"] == "127.0.0.1:${toString config.links.librespeed.port}" {
          server.document-root = "${librespeedAssets}"
        }
      '';

      rat.services.traefik.routes = {
        # Static frontend (lower priority via shorter rule).
        librespeed = {
          enable = true;
          inherit (cfg) subdomain;
          serviceUrl = config.links.librespeed.url;
          authentik = false;
          theme-park.app = "librespeed";
        };

        # Backend API (higher priority via PathPrefix, no response buffering).
        librespeed-backend = {
          enable = true;
          inherit (cfg) subdomain;
          path = "/backend/";
          serviceUrl = config.links.librespeed-backend.url;
          authentik = false;
        };
      };

      # Disable response buffering on the backend route for accurate speed test results
      # (replicates nginx proxy_buffering off / proxy_request_buffering off).
      services.traefik.dynamicConfigOptions.http.services.librespeed-backend.loadBalancer.responseForwarding.flushInterval = "-1ms";

      # Use a static user so the SQLite database under StateDirectory has stable
      # ownership across rebuilds and impermanence rollbacks. DynamicUser would
      # otherwise allocate a fresh UID per activation and leave the existing
      # /var/lib/librespeed inaccessible.
      systemd.services.librespeed.serviceConfig.DynamicUser = lib.mkForce false;
      systemd.services.librespeed.serviceConfig.User = "librespeed";
      systemd.services.librespeed.serviceConfig.Group = "librespeed";

      users.users.librespeed = {
        isSystemUser = true;
        group = "librespeed";
      };
      users.groups.librespeed = {};
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/librespeed";
          user = "librespeed";
          group = "librespeed";
        }
      ];
    })
  ];
}
