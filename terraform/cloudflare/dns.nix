{
  # DNS record pointing to the tunnel
  resource.cloudflare_record.ulysses-webhook = {
    zone_id = "\${ data.sops_file.cloudflare.data[\"zoneId\"] }";
    name = "ulysses-webhook";
    type = "CNAME";
    content = "\${ cloudflare_zero_trust_tunnel_cloudflared.ulysses-deploy.id }.cfargotunnel.com";
    proxied = true;
    comment = "Webhook endpoint for ulysses GitOps deployment";
  };
}
