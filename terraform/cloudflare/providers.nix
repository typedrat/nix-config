{
  terraform.required_providers = {
    cloudflare = {
      source = "cloudflare/cloudflare";
      version = "~> 4.0";
    };
    random = {
      source = "hashicorp/random";
    };
  };

  provider.cloudflare = {
    api_token = "\${ data.sops_file.cloudflare.data[\"apiToken\"] }";
  };
}
