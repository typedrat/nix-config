{
  authentik.applications.zipline = {
    name = "Zipline";
    group = "Media";
    icon = "https://raw.githubusercontent.com/diced/zipline/trunk/public/logo.png";
    description = "File upload and sharing";
    accessGroups = ["discord-sysop"];

    oauth2 = {
      clientId = "\${ data.sops_file.zipline.data[\"clientId\"] }";
      clientSecret = "\${ data.sops_file.zipline.data[\"clientSecret\"] }";
      launchUrl = "https://zipline.thisratis.gay/";
      redirectUris = [
        {
          url = "https://zipline.thisratis.gay/api/auth/oauth/oidc";
          matchingMode = "strict";
        }
      ];
    };
  };

  data.sops_file.zipline = {
    source_file = "../secrets/zipline.yaml";
  };
}
