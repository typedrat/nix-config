{
  authentik.applications.home-assistant = {
    name = "Home Assistant";
    group = "Home";
    icon = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/homeassistant.svg";
    description = "Home automation platform";
    accessGroups = ["discord-user"];

    oauth2 = {
      clientId = "\${ data.sops_file.home-assistant.data[\"oauth_client_id\"] }";
      clientSecret = "\${ data.sops_file.home-assistant.data[\"oauth_client_secret\"] }";
      launchUrl = "https://home.thisratis.gay/auth/oidc/welcome";
      redirectUris = [
        {
          url = "https://home.thisratis.gay/auth/external/callback";
          matchingMode = "strict";
        }
      ];
    };
  };

  data.sops_file.home-assistant = {
    source_file = "../secrets/home-assistant.yaml";
  };
}
