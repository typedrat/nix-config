{
  config,
  inputs,
  ...
}: {
  imports = [
    inputs.synapdeck.nixosModules.authentik-agent
    inputs.synapdeck.nixosModules.npm-cache
  ];

  sops.secrets."authentik-agent/enrollment-token" = {
    sopsFile = ../../secrets/authentik-agent.yaml;
    key = "enrollment_token";
    restartUnits = ["ak-sysd.service"];
  };

  services.authentik-agent = {
    enable = true;
    authentikUrl = "https://auth.synapdeck.com";
    enrollment = {
      enable = true;
      tokenFile = config.sops.secrets."authentik-agent/enrollment-token".path;
    };
  };

  services.npm-cache.enable = true;
}
