{
  resource.authentik_group = {
    "discord-user" = {
      name = "Discord Users";
      attributes = ''
        {
          "discord_role_id": "''${data.sops_file.authentik.data["discord.userRoleId"]}"
        }
      '';
    };
    "discord-sysop" = {
      name = "Discord Sysops";
      is_superuser = true;
      attributes = ''
        {
          "discord_role_id": "''${data.sops_file.authentik.data["discord.sysopRoleId"]}"
        }
      '';
    };
  };
}
