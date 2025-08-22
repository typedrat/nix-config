{
  authentik.applications.hydra = {
    name = "Hydra";
    group = "Development";
    icon = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/nixos.svg";
    description = "NixOS/Nix continuous integration system";
    accessGroups = ["discord-user"];

    entitlements = [
      {
        name = "Hydra Administrator";
        groups = ["discord-sysop"];
      }
      {
        name = "Hydra Create Projects";
        groups = ["discord-sysop"];
      }
      {
        name = "Hydra Restart Jobs";
        groups = ["discord-sysop"];
      }
      {
        name = "Hydra Cancel Build";
        groups = ["discord-sysop"];
      }
    ];

    ldap = {
      baseDn = "OU=hydra,DC=ldap,DC=goauthentik,DC=io";
      bindMode = "cached";
      searchMode = "cached";
      tlsServerName = "auth.thisratis.gay";
    };
  };
}
