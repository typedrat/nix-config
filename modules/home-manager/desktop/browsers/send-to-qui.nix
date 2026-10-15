{
  config,
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  browsersCfg = guiCfg.browsers or {};

  quiCfg = osConfig.rat.services.qui;
  inherit (osConfig.rat.services) domainName;
in {
  imports = [
    inputs.send-to-qui.homeModules.default
  ];

  config = lib.modules.mkIf (guiCfg.enable && browsersCfg.zen.enable) {
    rat.userSecrets.qui.apiKey = {};

    # Only the connection is managed; the defaults stay editable in the extension.
    programs.send-to-qui = {
      enable = true;
      apiKey.sopsSecret = "qui/apiKey";
      settings.baseUrl = "https://${quiCfg.subdomain}.${domainName}";
    };

    programs.zen-browser = {
      nativeMessagingHosts = [config.programs.send-to-qui.hostPackage];
      profiles.default.extensions.packages = [pkgs.send-to-qui];
    };
  };
}
