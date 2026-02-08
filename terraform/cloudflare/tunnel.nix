{
  # Random secret for the tunnel
  resource.random_id.ulysses-tunnel-secret = {
    byte_length = 32;
  };

  # Cloudflare Tunnel for ulysses webhook access
  resource.cloudflare_zero_trust_tunnel_cloudflared.ulysses-deploy = {
    account_id = "\${ data.sops_file.cloudflare.data[\"accountId\"] }";
    name = "ulysses-deploy";
    secret = "\${ random_id.ulysses-tunnel-secret.b64_std }";
  };

  # Tunnel configuration (ingress rules)
  resource.cloudflare_zero_trust_tunnel_cloudflared_config.ulysses-deploy = {
    account_id = "\${ data.sops_file.cloudflare.data[\"accountId\"] }";
    tunnel_id = "\${ cloudflare_zero_trust_tunnel_cloudflared.ulysses-deploy.id }";

    config = {
      ingress_rule = [
        {
          hostname = "ulysses-webhook.thisratis.gay";
          service = "http://127.0.0.1:9876";
        }
        {
          # Catch-all rule (required)
          service = "http_status:404";
        }
      ];
    };
  };

  # Output the tunnel token for use in NixOS configuration
  output.ulysses-tunnel-token = {
    value = "\${ cloudflare_zero_trust_tunnel_cloudflared.ulysses-deploy.tunnel_token }";
    sensitive = true;
    description = "Tunnel token for ulysses-deploy (use with cloudflared service)";
  };

  output.ulysses-tunnel-id = {
    value = "\${ cloudflare_zero_trust_tunnel_cloudflared.ulysses-deploy.id }";
    description = "Tunnel ID for ulysses-deploy";
  };
}
