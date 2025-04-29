{
  authentik.applications.grafana = {
    name = "Grafana";
    group = "System";
    icon = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/grafana.svg";
    description = "Analytics & monitoring solution";
    accessGroups = ["discord-user"];

    entitlements = [
      {
        name = "Grafana Editor";
        groups = []; # Users who can edit dashboards but not admin
      }
      {
        name = "Grafana Administrator";
        groups = ["discord-sysop"]; # Users who have full admin access
      }
    ];

    oauth2 = {
      clientId = "\${ data.sops_file.grafana.data[\"clientId\"] }";
      clientSecret = "\${ data.sops_file.grafana.data[\"clientSecret\"] }";
      launchUrl = "https://grafana.thisratis.gay/";
      redirectUris = [
        {
          url = "https://grafana.thisratis.gay/login/generic_oauth";
          matchingMode = "strict";
        }
      ];
    };
  };

  data.sops_file.grafana = {
    source_file = "../secrets/grafana.yaml";
  };
}
