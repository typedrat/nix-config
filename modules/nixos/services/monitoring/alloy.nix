{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;

  cfg = config.rat.services.alloy;
in {
  options.rat.services.alloy = {
    enable = options.mkEnableOption "Grafana Alloy";

    lokiSink = options.mkEnableOption ''
      a `loki.write "local"` component pointing at this host's Loki, shared by
      every log source in the Alloy configuration
    '';

    httpAddress = options.mkOption {
      type = types.str;
      default = "127.0.0.1:12345";
      description = "Address for Alloy's own UI and metrics endpoint.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.alloy = {
        enable = true;
        extraFlags = [
          "--server.http.listen-addr=${cfg.httpAddress}"
          "--disable-reporting"
        ];
      };
    })

    (modules.mkIf cfg.lokiSink {
      # Every `.alloy` file under /etc/alloy is parsed as one configuration, so
      # sources live in their own files and reference this component by name.
      environment.etc."alloy/write.alloy".text = ''
        loki.write "local" {
          endpoint {
            url = "${config.links.loki.url}/loki/api/v1/push"
          }
        }
      '';

      assertions = [
        {
          assertion = config.rat.services.loki.enable;
          message = "rat.services.alloy.lokiSink writes to this host's Loki, so rat.services.loki must be enabled too.";
        }
      ];
    })
  ];
}
