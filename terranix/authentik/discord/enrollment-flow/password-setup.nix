{
  resource = {
    authentik_stage_prompt."discord-enroll-password-setup" = {
      name = "discord-enrollment-password-setup-stage";

      fields = [
        "\${ authentik_stage_prompt_field.discord-enrollment-password.id }"
        "\${ authentik_stage_prompt_field.discord-enrollment-password-repeat.id }"
      ];

      validation_policies = [
        "\${ authentik_policy_password.discord-enrollment-password-strong.id }"
      ];
    };

    authentik_stage_prompt_field = {
      "discord-enrollment-password" = {
        name = "discord-enrollment-password-setup-password";
        field_key = "password";
        label = "Password";
        type = "password";
        required = true;
        placeholder = "Enter your new password";
      };

      "discord-enrollment-password-repeat" = {
        name = "discord-enrollment-password-setup-password-repeat";
        field_key = "password_repeat";
        label = "Confirm Password";
        type = "password";
        required = true;
        placeholder = "Confirm your new password";
      };
    };

    authentik_policy_password."discord-enrollment-password-strong" = {
      name = "discord-enrollment-password-strong";
      length_min = 8;
      error_message = "Your password must be at least 8 characters long.";

      check_zxcvbn = true;
      zxcvbn_score_threshold = 2;
    };
  };
}
