{
  terraform.required_providers = {
    github = {
      source = "integrations/github";
      version = "~> 6.0";
    };
  };

  provider.github = {
    owner = "typedrat";
    token = "\${ data.sops_file.github.data[\"token\"] }";
  };
}
