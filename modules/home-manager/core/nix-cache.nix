{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (config.home) username;
  cacheCfg = osConfig.rat.nix-cache;
  # The reader key lives in the shared file, which only the sops admin key can
  # open.
  hasSharedSecrets = username == "awilliams";
in {
  # The cache's store URI names this profile. The daemon substitutes with keys
  # from its environment, but client-side store access such as `nix log` runs
  # as the user and needs the profile to authenticate.
  config = lib.mkIf (cacheCfg.enable && hasSharedSecrets) {
    sops.secrets = {
      "nix-cache/reader/keyId" = {};
      "nix-cache/reader/applicationKey" = {};
    };

    sops.templates."aws-credentials" = {
      path = "${config.home.homeDirectory}/.aws/credentials";
      content = ''
        [${cacheCfg.profile}]
        aws_access_key_id = ${config.sops.placeholder."nix-cache/reader/keyId"}
        aws_secret_access_key = ${config.sops.placeholder."nix-cache/reader/applicationKey"}
      '';
    };
  };
}
