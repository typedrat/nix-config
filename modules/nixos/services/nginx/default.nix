{
  options,
  config,
  pkgs,
  lib,
  ...
}: let
  nginxOptions = options.services.nginx;
in let
  inherit (lib) attrsets modules options types;
  cfg = config.rat.services.nginx;
  domainName = config.rat.services.domainName;

  wrapVirtualHost = name: value: {
    name = "${name}.${domainName}";
    value = modules.mkMerge [
      (modules.mkIf cfg.http3.enable {
        locations = (
          builtins.mapAttrs (advertiseHTTP3On 443) value.locations
        );
      })
      (builtins.removeAttrs (patchVirtualHost value) ["authentik"])
    ];
  };

  patchVirtualHost = attrsets.updateManyAttrsByPath virtualHostPatches;

  virtualHostPatches = [
    {
      path = ["forceSSL"];
      update = _: true;
    }
    {
      path = ["kTLS"];
      update = _: true;
    }
    {
      path = ["useACMEHost"];
      update = _: lib.modules.mkForce domainName;
    }
    {
      path = ["quic"];
      update = _: cfg.quic.enable;
    }
    {
      path = ["http3"];
      update = _: cfg.http3.enable;
    }
  ];

  advertiseHTTP3On = port: _name: _location: {
    extraConfig = ''
      add_header Alt-Svc 'h3=\":${toString port}\"; ma=86400;';
    '';
  };
in {
  imports = [
    ./authentik.nix
  ];

  options.rat.services.nginx = {
    enable = options.mkEnableOption "nginx";
    package = options.mkPackageOption pkgs "nginx" {
      default =
        if cfg.quic.enable
        then "nginxQuic"
        else "nginx";
    };
    quic.enable = options.mkOption {
      type = types.bool;
      default = cfg.http3.enable;
      description = "Whether to enable the QUIC transport protocol.";
    };
    http3.enable = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the HTTP/3 transport protocol.";
    };

    virtualHosts = options.mkOption {
      inherit (nginxOptions.virtualHosts) default description example type;
    };
  };

  config = modules.mkIf cfg.enable {
    services.nginx = {
      package = cfg.package;
      enable = true;
      enableReload = true;
      enableQuicBPF = modules.mkIf cfg.quic.enable true;
      additionalModules = with pkgs.nginxModules; [
        moreheaders
      ];

      recommendedOptimisation = true;
      recommendedBrotliSettings = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedZstdSettings = true;

      statusPage = true;

      defaultSSLListenPort = 443;
      virtualHosts = modules.mkMerge [
        {
          "_" = {
            default = true;
            locations."/" = {
              return = "404";
            };
          };
        }
        (lib.mapAttrs' wrapVirtualHost cfg.virtualHosts)
      ];
    };

    security.acme.certs.${domainName} = {
      domain = domainName;
      extraDomainNames = ["*.${domainName}"];
      group = "nginx";
    };

    networking.firewall = {
      allowedTCPPorts = [
        80
        443
      ];
      allowedUDPPorts = [
        443
      ];
    };
  };
}
