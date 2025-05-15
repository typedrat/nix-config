{links, ...}: {
  terraform.required_providers = {
    lidarr = {
      source = "devopsarr/lidarr";
    };
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
    lidarr = {
      api_key = "\${ data.sops_file.arrs.data[\"lidarr.apiKey\"] }";
      inherit (links.lidarr) url;
    };
    radarr = [
      {
        api_key = "\${ data.sops_file.arrs.data[\"radarr.apiKey\"] }";
        inherit (links.radarr) url;
      }
      {
        api_key = "\${ data.sops_file.arrs.data[\"radarr-anime.apiKey\"] }";
        inherit (links.radarr-anime) url;
        alias = "anime";
      }
    ];
    sonarr = [
      {
        api_key = "\${ data.sops_file.arrs.data[\"sonarr.apiKey\"] }";
        inherit (links.sonarr) url;
      }
      {
        api_key = "\${ data.sops_file.arrs.data[\"sonarr-anime.apiKey\"] }";
        inherit (links.sonarr-anime) url;
        alias = "anime";
      }
    ];
    prowlarr = {
      api_key = "\${ data.sops_file.arrs.data[\"prowlarr.apiKey\"] }";
      inherit (links.prowlarr) url;
    };
  };
}
