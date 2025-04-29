{
  authentik.applications.traefik = {
    name = "Traefik";
    group = "System";
    icon = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/traefik-proxy.svg";
    description = "Modern reverse proxy and load balancer";
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://traefik.thisratis.gay";
    };
  };
}
