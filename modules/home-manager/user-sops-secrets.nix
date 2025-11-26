{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (config.home) username;

  # Check if user needs B2 secrets
  needsB2Secrets = username == "awilliams";
  # Check if user needs work GDrive secrets
  needsWorkGdriveSecrets = username == "awilliams";
in {
  config = {
    sops.secrets = lib.mkMerge [
      # B2 secrets for awilliams
      (mkIf needsB2Secrets {
        "b2/keyId" = {};
        "b2/applicationKey" = {};
      })

      # Work GDrive secrets for awilliams
      (mkIf needsWorkGdriveSecrets {
        work-gdrive-sa-key = {
          format = "json";
          sopsFile = ../../secrets/synapdeck-gdrive.json;
          key = "";
        };
      })
    ];
  };
}
