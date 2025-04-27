{
  imports = [
    ./settings.nix
  ];

  data.authentik_flow."default-authorization-flow" = {
    slug = "default-provider-authorization-implicit-consent";
  };

  data.authentik_flow."default-source-enrollment" = {
    slug = "default-source-enrollment";
  };

  data.authentik_flow."default-provider-invalidation-flow" = {
    slug = "default-provider-invalidation-flow";
  };

  data.authentik_flow."default-authentication-flow" = {
    slug = "default-authentication-flow";
  };

  data.authentik_flow."default-invalidation-flow" = {
    slug = "default-invalidation-flow";
  };
}
