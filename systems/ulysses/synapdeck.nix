{inputs, ...}: {
  imports = [
    inputs.synapdeck.nixosModules.authentik-agent
    inputs.synapdeck.nixosModules.npm-cache
  ];

  services.authentik-agent = {
    enable = true;
    authentikUrl = "https://auth.synapdeck.com";
  };

  services.npm-cache.enable = true;
}
