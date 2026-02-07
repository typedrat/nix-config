{
  inputs,
  self,
  ...
}: {
  imports = [
    inputs.terranix.flakeModule
  ];
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    terranix = {
      terranixConfigurations = {
        terraform = {
          terraformWrapper = {
            package = pkgs.opentofu;
            extraRuntimeInputs = [pkgs.sops pkgs.openssh];
            prefixText = let
              target_host = "iserlohn.thisratis.gay";
              links_to_tunnel = [
                "lidarr"
                "prowlarr"
                "radarr"
                "radarr-anime"
                "sonarr"
                "sonarr-anime"
              ];

              mkPortForward = _key: port: "-L ${toString port}:localhost:${toString port}";
              portForwards = builtins.concatStringsSep " " (
                map
                (key: mkPortForward key (self.nixosConfigurations.iserlohn.config.links.${key}.port or null))
                links_to_tunnel
              );
            in ''
              AWS_ACCESS_KEY_ID=$(sops decrypt ../secrets/default.yaml --extract '["b2"]["keyId"]')
              AWS_SECRET_ACCESS_KEY=$(sops decrypt ../secrets/default.yaml --extract '["b2"]["applicationKey"]')
              TF_VAR_passphrase=$(sops decrypt ../secrets/default.yaml --extract '["terraformPassphrase"]')
              export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY TF_VAR_passphrase

              SSH_CONTROL_PATH=$(mktemp -tu .ssh.sock.XXXXXX)

              echo "Setting up SSH tunnels to ${target_host}..."
              ssh -M -S "$SSH_CONTROL_PATH" -fNT ${portForwards} "${target_host}"
              echo "SSH tunnels established using control socket: $SSH_CONTROL_PATH"

              function cleanup_ssh_tunnel() {
                if [ -S "$SSH_CONTROL_PATH" ]; then
                  echo "Closing SSH tunnel control socket..."
                  ssh -S "$SSH_CONTROL_PATH" -O exit "${target_host}" 2>/dev/null || true
                  echo "SSH tunnel terminated."
                fi
              }

              trap cleanup_ssh_tunnel EXIT
            '';
          };

          modules = [
            {
              _module.args = {
                inherit (self.nixosConfigurations.iserlohn.config) links;
              };
            }

            ../terraform
          ];
        };
      };
    };

    packages = builtins.listToAttrs (map
      (
        key: {
          name = "${key}.tf.json";
          value = config.terranix.terranixConfigurations.${key}.result.terraformConfiguration;
        }
      )
      (builtins.attrNames config.terranix.terranixConfigurations));
  };
}
