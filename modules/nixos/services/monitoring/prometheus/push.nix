{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;

  cfg = config.rat.services.prometheus.push;

  instance = config.networking.hostName;

  target = link: job: ''{ __address__ = "${link.tuple}", job = "${job}", instance = "${instance}" }'';
in {
  options.rat.services.prometheus.push = {
    target = options.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "iserlohn.lan";
      description = ''
        Host running a Prometheus remote-write receiver to push this machine's
        metrics to.

        Scraping happens locally over loopback, so the sample rate is not
        bounded by how often something across the network gets around to
        asking, and the collector does not need to be able to reach this host
        at all. Nothing here has to be exposed to the network.
      '';
    };

    interval = options.mkOption {
      type = types.str;
      default = "1s";
      description = ''
        How often to sample the node and ZFS exporters. Also used as the scrape
        timeout, which has to be no larger than the interval.
      '';
    };
  };

  config = modules.mkIf (cfg.target != null) {
    rat.services.alloy.enable = true;

    environment.etc."alloy/metrics.alloy".text = ''
      prometheus.scrape "host" {
        targets = [
          ${target config.links.prometheus-node "node"},
          ${target config.links.prometheus-zfs "zfs"},
        ]

        scrape_interval = "${cfg.interval}"
        scrape_timeout  = "${cfg.interval}"
        forward_to      = [prometheus.remote_write.upstream.receiver]
      }

      // SMART attributes are refreshed by the exporter once a minute and
      // querying a disk is slow enough to be worth avoiding, so this one keeps
      // its own pace.
      prometheus.scrape "disks" {
        targets = [
          ${target config.links.prometheus-smartctl "smartctl"},
        ]

        scrape_interval = "1m"
        forward_to      = [prometheus.remote_write.upstream.receiver]
      }

      prometheus.remote_write "upstream" {
        endpoint {
          url = "http://${cfg.target}:${config.links.prometheus.portStr}/api/v1/write"

          queue_config {
            // Anything still sitting in the WAL when the machine wedges is
            // never sent, so flush on a deadline close to the sample rate
            // rather than the usual multi-second batch.
            batch_send_deadline = "1s"
          }
        }
      }
    '';
  };
}
