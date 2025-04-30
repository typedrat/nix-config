{
  authentik.applications.autobrr = {
    name = "Autobrr";
    group = "Torrents";
    icon = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/autobrr.svg";
    description = "Automated torrent downloader";
    accessGroups = ["discord-sysop"];

    oauth2 = {
      clientId = "\${ data.sops_file.autobrr.data[\"clientId\"] }";
      clientSecret = "\${ data.sops_file.autobrr.data[\"clientSecret\"] }";
      launchUrl = "https://autobrr.thisratis.gay/";
      redirectUris = [
        {
          url = "https://autobrr.thisratis.gay/api/auth/oidc/callback";
          matchingMode = "strict";
        }
      ];
    };
  };

  data.sops_file.autobrr = {
    source_file = "../secrets/autobrr.yaml";
  };
}
