{
  pkgs,
  osConfig,
  ...
}: {
  services.podman = {
    enable = true;

    settings = {
      registries.search = osConfig.virtualisation.containers.registries.search;

      storage = {
        storage = {
          driver = "overlay";
        };

        storage.options.overlay = {
          mount_program = "${pkgs.fuse-overlayfs}";
        };
      };
    };
  };

  home.packages = with pkgs; [
    fuse-overlayfs
    passt
    dive
    lazydocker
  ];

  home.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
}
