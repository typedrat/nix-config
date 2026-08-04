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
      default = config.links.alloy.tuple;
      defaultText = options.literalExpression "config.links.alloy.tuple";
      description = "Address for Alloy's own UI and metrics endpoint.";
    };
  };

  config = modules.mkMerge [
    {
      # Alloy's own default is 12345, which sits outside the reserved range and
      # is a popular pick for dev servers. Going through port-magic moves it
      # into the reserved band and makes a collision an eval error rather than
      # a service that quietly loses the race for the port.
      links.alloy = {
        protocol = "http";
      };
    }

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
