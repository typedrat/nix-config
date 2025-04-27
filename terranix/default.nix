{
  imports = [
    ./authentik
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
          keys = "\${ key_provider.pbkdf2.enc_key }";
        };

        state = {
          method = "\${ method.aes_gcm.enc_method }";
        };
      };

      backend.s3 = rec {
        bucket = "typedrat-terraform-state";
        key = "terraform.tfstate";
        region = "us-west-002";
        endpoints = {
          s3 = "https://s3.${region}.backblazeb2.com";
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
