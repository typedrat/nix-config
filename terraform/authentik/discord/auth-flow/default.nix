{lib, ...}: {
  resource = {
    authentik_flow."discord-auth" = rec {
      name = "Authenticate with Discord";
      title = name;
      slug = "discord-authentication-flow";
      designation = "authentication";
      authentication = "require_unauthenticated";
    };

    authentik_stage_user_login."discord-auth-login" = {
      name = "discord-authentication-login";
    };

    authentik_flow_stage_binding."discord-auth-bind-login" = {
      target = "\${ authentik_flow.discord-auth.uuid }";
      stage = "\${ authentik_stage_user_login.discord-auth-login.id }";
      re_evaluate_policies = true;
      order = 0;
    };

    authentik_policy_expression."discord-auth-policy-guild-sync" = {
      name = "discord-authentication-policy-guild-sync";
      expression = lib.concatLines [
        "GUILD_ID = \"\${data.sops_file.authentik.data[\"discord.guildId\"]}\""
        "GUILD_NAME = \"\${data.sops_file.authentik.data[\"discord.guildName\"]}\""
        (builtins.readFile ./guild-sync.py)
      ];
    };

    authentik_policy_binding."discord-auth-bind-policy-guild-sync" = {
      target = "\${ authentik_flow_stage_binding.discord-auth-bind-login.id }";
      policy = "\${ authentik_policy_expression.discord-auth-policy-guild-sync.id }";
      order = 0;
    };
  };
}
