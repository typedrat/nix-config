{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  securityKeyCfg = userCfg.securityKey or {};
  gpgCfg = securityKeyCfg.gpg or {};
  agentCfg = securityKeyCfg.agent or {};
in {
  config = mkIf (securityKeyCfg.enable or false) {
    programs.gpg = mkIf (gpgCfg.enable or true) {
      enable = true;
      scdaemonSettings = gpgCfg.scdaemonSettings or {};
    };

    services.gpg-agent = mkIf (agentCfg.enable or true) {
      enable = true;
      enableZshIntegration = true;

      pinentry.package = agentCfg.pinentryPackage;
      defaultCacheTtl = agentCfg.defaultCacheTtl or 600;
      maxCacheTtl = agentCfg.maxCacheTtl or 7200;
      enableSshSupport = agentCfg.enableSshSupport or false;
    };
  };
}
