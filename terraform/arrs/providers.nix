{links, ...}: {
  terraform.required_providers = {
    prowlarr = {
      source = "devopsarr/prowlarr";
    };
    radarr = {
      source = "devopsarr/radarr";
    };
    sonarr = {
      source = "devopsarr/sonarr";
    };
  };

  provider = {
    radarr = [
      {
        api_key = "\${ data.sops_file.arrs.data[\"radarr.apiKey\"] }";
        url = links.radarr.url;
      }
      {
        api_key = "\${ data.sops_file.arrs.data[\"radarr-anime.apiKey\"] }";
        url = links.radarr-anime.url;
        alias = "anime";
      }
    ];
    sonarr = [
      {
        api_key = "\${ data.sops_file.arrs.data[\"sonarr.apiKey\"] }";
        url = links.sonarr.url;
      }
      {
        api_key = "\${ data.sops_file.arrs.data[\"sonarr-anime.apiKey\"] }";
        url = links.sonarr-anime.url;
        alias = "anime";
      }
    ];
    prowlarr = {
      api_key = "\${ data.sops_file.arrs.data[\"prowlarr.apiKey\"] }";
      url = links.prowlarr.url;
    };
  };
}
