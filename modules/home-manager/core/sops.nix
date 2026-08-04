{
  config,
  osConfig,
  inputs,
  lib,
  ...
}: let
  inherit (lib) attrsets modules options types;
  inherit (config.home) username;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  cfg = config.rat.userSecrets;

  secretFile = file: config.rat.userSecretsDir + "/${file}.yaml";

  # Secrets are named "<file>/<key>" so that two files can declare the same key
  # without colliding in the flat sops.secrets namespace.
  fileSecrets = file:
    attrsets.mapAttrs' (
      key: secretCfg:
        attrsets.nameValuePair "${file}/${key}" ({
            sopsFile = secretFile file;
            inherit key;
          }
          // secretCfg)
    );
in {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  options.rat.userSecretsDir = options.mkOption {
    type = types.path;
    readOnly = true;
    default = ../../../secrets + "/${username}";
    description = "Directory holding this user's own SOPS files.";
  };

  options.rat.userSecrets = options.mkOption {
    type = types.attrsOf (types.attrsOf (types.submodule {
      freeformType = types.attrsOf types.anything;
    }));
    default = {};
    example = options.literalExpression ''
      {
        anki = {
          username = {};
          syncKey = {};
        };
      }
    '';
    description = ''
      Secrets belonging to this user alone, declared as
      `rat.userSecrets.<file>.<key>`. Each entry decrypts `<key>` out of
      `secrets/<username>/<file>.yaml` and exposes it as
      `config.sops.secrets."<file>/<key>"`. Attributes set on an entry are
      passed through to the underlying sops secret.
    '';
  };

  config = {
    sops = {
      defaultSopsFile = ../../../secrets/default.yaml;
      age.sshKeyPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];

      secrets = attrsets.concatMapAttrs fileSecrets cfg;
    };

    assertions =
      attrsets.mapAttrsToList (file: _: {
        assertion = builtins.pathExists (secretFile file);
        message = "rat.userSecrets.${file} needs secrets/${username}/${file}.yaml, which does not exist.";
      })
      cfg;

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/sops" ".config/sops-nix"];
    };
  };
}
