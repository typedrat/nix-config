{
  imports = [
    ./applications
    ./discord
    ./flows
    ./branding.nix
    ./ldap-search.nix
    ./outposts.nix
  ];

  config = {
    terraform = {
      required_providers = {
        authentik = {
          source = "goauthentik/authentik";
          version = "~> 2025.8.0";
        };
      };
    };

    provider.authentik = {
      url = "https://auth.thisratis.gay";
      token = "\${ data.sops_file.authentik.data[\"bootstrap.token\"] }";
    };

    data.sops_file.authentik = {
      source_file = "../secrets/authentik.yaml";
    };
  };
}
