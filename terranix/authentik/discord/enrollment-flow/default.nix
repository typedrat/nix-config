{lib, ...}: {
  imports = [
    ./password-setup.nix
  ];

  resource = {
    authentik_flow."discord-enroll" = rec {
      name = "Discord User Enrollment";
      title = name;
      slug = "discord-enrollment-flow";
      designation = "enrollment";
    };

    authentik_flow_stage_binding."discord-enroll-bind-password-setup" = {
      target = "\${ authentik_flow.discord-enroll.uuid }";
      stage = "\${ authentik_stage_prompt.discord-enroll-password-setup.id }";
      re_evaluate_policies = true;
      order = 0;
    };

    authentik_policy_expression."discord-enroll-policy-guild-sync" = {
      name = "discord-enrollment-policy-guild-sync";
      expression = lib.concatLines [
        "GUILD_ID = \"\${data.sops_file.authentik.data[\"discord.guildId\"]}\""
        "GUILD_NAME = \"\${data.sops_file.authentik.data[\"discord.guildName\"]}\""
        (builtins.readFile ./guild-sync.py)
      ];
    };

    authentik_policy_binding."discord-enroll-bind-policy-guild-sync" = {
      target = "\${ authentik_flow_stage_binding.discord-enroll-bind-password-setup.id }";
      policy = "\${ authentik_policy_expression.discord-enroll-policy-guild-sync.id }";
      order = 0;
    };

    authentik_stage_user_write."discord-enroll-user-write" = {
      name = "discord-enrollment-user-write-stage";
      user_creation_mode = "always_create";
      create_users_as_inactive = false;
      user_type = "internal";
    };

    authentik_flow_stage_binding."discord-enroll-bind-user-write" = {
      target = "\${ authentik_flow.discord-enroll.uuid }";
      stage = "\${ authentik_stage_user_write.discord-enroll-user-write.id }";
      order = 5;
    };

    authentik_stage_user_login."discord-enroll-user-login" = {
      name = "discord-enrollment-user-login-stage";
    };

    authentik_flow_stage_binding."discord-enroll-bind-user-login" = {
      target = "\${ authentik_flow.discord-enroll.uuid }";
      stage = "\${ authentik_stage_user_login.discord-enroll-user-login.id }";
      order = 10;
    };
  };
}
