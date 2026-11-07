{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  guiCfg = osConfig.rat.users.${username}.gui or {};
  chatCfg = guiCfg.chat or {};
  impermanenceCfg = osConfig.rat.impermanence;
in {
  config = modules.mkIf (guiCfg.enable && chatCfg.enable && chatCfg.halloy.enable) {
    home.persistence.${impermanenceCfg.persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".local/share/halloy"];
    };

    programs.halloy = {
      enable = true;
      settings = {
        notifications = {
          direct_message = {
            sound = "zone";
            show_toast = true;
          };
          highlight = {
            sound = "zone";
            show_toast = true;
          };
        };

        buffer.chathistory.infinite_scroll = true;

        # Every network is configured on the bouncer, and Halloy discovers them
        # from it. Halloy prompts for the keyring password on first use and
        # keeps it in the Secret Service.
        servers.soju = {
          nickname = "ratmilk";
          server = "irc.thisratis.gay";
          use_tls = true;
          port = 6697;
          sasl.plain = {
            username = "typedrat";
            password_keyring = true;
          };
        };
      };
    };

    # Replaces a file Halloy created as an ordinary writable one, which
    # home-manager would otherwise refuse to overwrite.
    xdg.configFile."halloy/config.toml".force = true;
  };
}
