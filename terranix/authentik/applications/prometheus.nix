{
  authentik.applications.prometheus = {
    name = "Prometheus";
    group = "System";
    icon = "https://github.com/loganmarchione/homelab-svg-assets/raw/refs/heads/main/assets/prometheus.svg";
    description = "An open-source monitoring and alerting toolkit.";
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://prometheus.thisratis.gay";
    };
  };
}
