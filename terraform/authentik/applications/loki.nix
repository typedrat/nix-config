{
  authentik.applications.loki = {
    name = "Loki";
    group = "System";
    icon = "https://github.com/loganmarchione/homelab-svg-assets/raw/refs/heads/main/assets/loki.svg";
    description = "An open-source, highly scalable, multi-tenant log aggregation system.";
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://loki.thisratis.gay";
    };
  };
}
