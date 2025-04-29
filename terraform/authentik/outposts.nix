{
  config,
  lib,
  ...
}: let
  inherit (lib) types mkOption;
  outpostConfig = {
    authentik_host = "https://auth.thisratis.gay/";
    authentik_host_browser = "";
    authentik_host_insecure = false;
    container_image = null;
    docker_labels = null;
    docker_map_ports = true;
    docker_network = null;
    kubernetes_disabled_components = [];
    kubernetes_image_pull_secrets = [];
    kubernetes_ingress_annotations = {};
    kubernetes_ingress_class_name = null;
    kubernetes_ingress_secret_name = "authentik-outpost-tls";
    kubernetes_json_patches = null;
    kubernetes_namespace = "authentik";
    kubernetes_replicas = 1;
    kubernetes_service_type = "ClusterIP";
    log_level = "info";
    object_naming_template = "ak-outpost-%(name)s";
    refresh_interval = "minutes=5";
  };
in {
  options.authentik.outposts = {
    ldap.providers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of LDAP provider IDs";
    };

    proxy.providers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of Proxy provider IDs";
    };
  };

  config.resource = {
    authentik_outpost = {
      embedded-outpost = {
        name = "authentik Embedded Outpost";
        protocol_providers = config.authentik.outposts.proxy.providers;
      };

      ldap = {
        name = "LDAP Outpost";
        type = "ldap";
        config = builtins.toJSON outpostConfig;
        protocol_providers = config.authentik.outposts.ldap.providers;
      };
    };
  };
}
