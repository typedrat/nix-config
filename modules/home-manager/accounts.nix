let
  makeGmail = {
    address,
    realName,
    primary ? false,
  }: {
    inherit address realName primary;
    userName = address;

    flavor = "gmail.com";

    thunderbird = {
      enable = true;
      settings = id: {
        "mail.identity.id_${id}.protectSubject" = false;
        "mail.identity.id_${id}.compose_html" = false;
        "mail.identity.id_${id}.reply_on_top" = 0;
        "mail.server.server_${id}.authMethod" = 10;
        "mail.smtpserver.smtp_${id}.authMethod" = 10;
      };
    };
  };
in {
  accounts.email.accounts = {
    Personal = makeGmail {
      realName = "Alexis Williams";
      address = "alexis@typedr.at";
      primary = true;
    };

    Backup = makeGmail {
      realName = "Alexis Williams";
      address = "typedrat@gmail.com";
    };

    Work = makeGmail {
      realName = "Alexis Williams";
      address = "alexis@synapdeck.com";
    };
  };
}
