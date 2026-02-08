{
  resource.github_repository_webhook = {
    deploy-iserlohn = {
      repository = "nix-config";

      configuration = {
        url = "https://iserlohn-webhook.thisratis.gay/hooks/deploy";
        content_type = "json";
        secret = "\${ data.sops_file.deploy.data[\"webhookSecret\"] }";
        insecure_ssl = false;
      };

      events = ["workflow_job"];
      active = true;
    };

    deploy-ulysses = {
      repository = "nix-config";

      configuration = {
        url = "https://ulysses-webhook.thisratis.gay/hooks/deploy";
        content_type = "json";
        secret = "\${ data.sops_file.deploy.data[\"webhookSecret\"] }";
        insecure_ssl = false;
      };

      events = ["workflow_job"];
      active = true;
    };
  };
}
