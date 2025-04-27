let
  discordGroup = name: key: {
    inherit name;
    attributes = ''
      {
        "discord_role_id": "''${data.sops_file.authentik.data["discord.${key}"]}"
      }
    '';
  };
in {
  resource.authentik_group = {
    "discord-user" = discordGroup "Discord Users" "userRoleId";
    "discord-sysop" =
      discordGroup "Discord Sysops" "sysopRoleId"
      // {
        is_superuser = true;
      };
  };
}
