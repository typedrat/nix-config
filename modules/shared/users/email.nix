{lib, ...}: let
  inherit (lib) options types;

  emailAccountOptions = types.submodule {
    options = {
      address = options.mkOption {
        type = types.str;
        description = "Email address";
        example = "user@example.com";
      };

      realName = options.mkOption {
        type = types.str;
        description = "Real name to use for this email account";
        example = "John Doe";
      };

      primary = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether this is the primary email account";
      };

      flavor = options.mkOption {
        type = types.str;
        default = "gmail.com";
        description = "Email provider flavor (gmail.com, plain, etc.)";
        example = "gmail.com";
      };

      userName = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Username for authentication (defaults to address if null)";
        example = "user@example.com";
      };

      thunderbird = {
        enable = options.mkOption {
          type = types.bool;
          default = true;
          description = "Whether to enable this account in Thunderbird";
        };

        protectSubject = options.mkOption {
          type = types.bool;
          default = false;
          description = "Whether to protect email subject in Thunderbird";
        };

        composeHtml = options.mkOption {
          type = types.bool;
          default = false;
          description = "Whether to compose emails in HTML by default";
        };

        replyOnTop = options.mkOption {
          type = types.int;
          default = 0;
          description = "Reply position (0 = below quote, 1 = above quote)";
        };

        authMethod = options.mkOption {
          type = types.int;
          default = 10;
          description = "Authentication method (10 = OAuth2)";
        };
      };
    };
  };

  emailOptions = types.submodule {
    options = {
      accounts = options.mkOption {
        type = types.attrsOf emailAccountOptions;
        default = {};
        description = "Email account configurations";
        example = {
          Personal = {
            address = "john@example.com";
            realName = "John Doe";
            primary = true;
          };
        };
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.email = options.mkOption {
        type = emailOptions;
        default = {};
        description = "Email configuration for this user";
      };
    });
  };
}
