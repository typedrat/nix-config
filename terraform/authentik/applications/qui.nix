{
  authentik.applications.qui = {
    name = "Qui";
    group = "Media";
    icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/qui.svg";
    description = "Download management interface for qBittorrent";
    accessGroups = [ "discord-user" ];

    oauth2 = {
      clientId = "qui";
      clientSecret = "\${ data.sops_file.qui.data[\"oidcClientSecret\"] }";
      launchUrl = "https://qui.thisratis.gay/";
      redirectUris = [
        {
          url = "https://qui.thisratis.gay/api/auth/oidc/callback";
          matchingMode = "strict";
        }
      ];
    };
  };

  data.sops_file.qui = {
    source_file = "../secrets/qui.yaml";
  };
}
