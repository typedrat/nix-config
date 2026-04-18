{
  imports = [
    ./auth-flow
    ./enrollment-flow
    ./role-groups.nix
  ];

  config = {
    locals = {
      # nonsensitive() so that expressions referencing these don't get tainted
      # as sensitive in state, which causes spurious dirty-on-every-apply diffs
      discord_guild_id = "\${ nonsensitive(data.sops_file.authentik.data[\"discord.guildId\"]) }";
      discord_guild_name = "\${ nonsensitive(data.sops_file.authentik.data[\"discord.guildName\"]) }";
    };

    resource = {
      authentik_source_oauth.discord = {
        name = "Discord";
        slug = "discord";
        authentication_flow = "\${ authentik_flow.discord-auth.uuid }";
        enrollment_flow = "\${ authentik_flow.discord-enroll.uuid }";

        provider_type = "discord";
        consumer_key = "\${ data.sops_file.authentik.data[\"discord.clientId\"] }";
        consumer_secret = "\${ data.sops_file.authentik.data[\"discord.clientSecret\"] }";
        additional_scopes = "guilds guilds.members.read";
      };

      authentik_stage_identification."default-authentication-identification" = {
        name = "default-authentication-identification";
        user_fields = [];
        sources = ["\${ authentik_source_oauth.discord.uuid }"];
      };
    };
  };
}
