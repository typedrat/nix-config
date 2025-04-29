{
  authentik.applications.jellyfin = {
    name = "Jellyfin";
    group = "Streaming";
    icon = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/jellyfin.svg";
    description = "The Free Software Media System.";
    accessGroups = ["discord-user"];

    oauth2 = {
      clientId = "\${ data.sops_file.jellyfin.data[\"clientId\"] }";
      clientSecret = "\${ data.sops_file.jellyfin.data[\"clientSecret\"] }";
      launchUrl = "https://jellyfin.thisratis.gay/sso/OID/start/authentik";
      redirectUris = [
        {
          url = "https://jellyfin.thisratis.gay/sso/OID/redirect/authentik";
          matchingMode = "strict";
        }
      ];
      backchannelLdap = {
        baseDn = "OU=jellyfin,DC=ldap,DC=goauthentik,DC=io";
        bindMode = "cached";
        searchMode = "cached";
        tlsServerName = "auth.thisratis.gay";
      };
    };
  };

  data.sops_file.jellyfin = {
    source_file = "../secrets/jellyfin.yaml";
  };
}
