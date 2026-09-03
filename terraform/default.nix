{
  imports = [
    ./arrs
    ./authentik
    ./cloudflare
    ./github
    ./sops.nix
  ];

  config = {
    variable."passphrase" = {
      type = "string";
    };

    terraform = {
      encryption = {
        key_provider.pbkdf2.enc_key = {
          passphrase = "\${ var.passphrase }";
        };

        method.aes_gcm.enc_method = {
          keys = "key_provider.pbkdf2.enc_key";
        };

        state = {
          method = "method.aes_gcm.enc_method";
        };
      };

      # Cloudflare R2. The account id is not a secret in the way the API
      # token is -- it appears in every R2 endpoint URL -- but it lives in
      # sops with the rest of the Cloudflare config, and a backend block
      # cannot interpolate, so it is spelled out here.
      backend.s3 = {
        bucket = "typedrat-terraform-state";
        key = "terraform.tfstate";
        # R2 presents a single global region.
        region = "auto";
        endpoints = {
          s3 = "https://be548483948975c1a68eebfc032a31ff.r2.cloudflarestorage.com";
        };

        skip_credentials_validation = true;
        skip_region_validation = true;
        skip_metadata_api_check = true;
        skip_requesting_account_id = true;
        skip_s3_checksum = true;
      };
    };
  };
}
