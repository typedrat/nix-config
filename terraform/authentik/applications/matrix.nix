{
  authentik.applications = {
    matrix = {
      name = "Matrix";
      group = "Communication";
      icon = "https://github.com/loganmarchione/homelab-svg-assets/raw/refs/heads/main/assets/matrix-white.svg";
      description = "Secure, decentralized communication platform";
      accessGroups = ["discord-user"];

      oauth2 = {
        clientId = "\${ data.sops_file.matrix.data[\"authentik.clientId\"] }";
        clientSecret = "\${ data.sops_file.matrix.data[\"authentik.clientSecret\"] }";
        launchUrl = "blank://blank";
        redirectUris = [
          {
            url = "https://matrix-auth.thisratis.gay/upstream/callback/.*";
            matchingMode = "regex";
          }
        ];
      };
    };

    element = {
      name = "Element Web";
      group = "Communication";
      icon = "https://github.com/loganmarchione/homelab-svg-assets/raw/refs/heads/main/assets/element.svg";
      description = "Feature-rich Matrix client with end-to-end encryption";
      accessGroups = ["discord-user"];

      proxy = {
        externalHost = "https://element.thisratis.gay";
      };
    };
  };

  data.sops_file.matrix = {
    source_file = "../secrets/matrix.yaml";
  };
}
