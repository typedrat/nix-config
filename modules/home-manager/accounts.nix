{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  emailCfg = userCfg.email or {};
  emailAccounts = emailCfg.accounts or {};

  makeEmailAccount = name: accountCfg: let
    # Compute userName, defaulting to address if userName is null or not set
    finalUserName = if (accountCfg.userName or null) != null then accountCfg.userName else accountCfg.address;
  in {
    address = accountCfg.address;
    realName = accountCfg.realName;
    primary = accountCfg.primary;
    userName = finalUserName;
    flavor = accountCfg.flavor;

    # Set smtp configuration to prevent git sendemail from using null values
    smtp = {
      host = "smtp.gmail.com";
      port = 587;
      tls.useStartTls = true;
    };

    thunderbird = mkIf accountCfg.thunderbird.enable {
      enable = true;
      settings = id: {
        "mail.identity.id_${id}.protectSubject" = accountCfg.thunderbird.protectSubject;
        "mail.identity.id_${id}.compose_html" = accountCfg.thunderbird.composeHtml;
        "mail.identity.id_${id}.reply_on_top" = accountCfg.thunderbird.replyOnTop;
        "mail.server.server_${id}.authMethod" = accountCfg.thunderbird.authMethod;
        "mail.smtpserver.smtp_${id}.authMethod" = accountCfg.thunderbird.authMethod;
      };
    };
  };
in {
  config = mkIf (emailAccounts != {}) {
    accounts.email.accounts = mapAttrs makeEmailAccount emailAccounts;
  };
}
