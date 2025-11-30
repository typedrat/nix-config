{
  authentik.applications.romm = {
    name = "RomM";
    group = "Games";
    icon = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/romm.svg";
    description = "ROM Manager for game collections";
    accessGroups = ["discord-user"];

    oauth2 = {
      clientId = "\${ data.sops_file.romm.data[\"oidc.client_id\"] }";
      clientSecret = "\${ data.sops_file.romm.data[\"oidc.client_secret\"] }";
      launchUrl = "https://romm.thisratis.gay/";
      redirectUris = [
        {
          url = "https://romm.thisratis.gay/api/oauth/openid";
          matchingMode = "strict";
        }
      ];
    };
  };

  data.sops_file.romm = {
    source_file = "../secrets/romm.yaml";
  };
}
