{
  inputs,
  lib,
  ...
}: {
  config = {
    nixpkgs = {
      overlays = [
        inputs.vscode-extensions.overlays.default
      ];

      config = {
        allowUnfree = true;

        permittedInsecurePackages = [
          "fluffychat-linux-1.26.0"
          "olm-3.2.16"
        ];
      };
    };

    nix = let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in {
      settings = {
        experimental-features = "nix-command flakes";
        trusted-users = ["awilliams"];
      };
      # Opinionated: disable channels
      channel.enable = false;

      # Opinionated: make flake registry and nix path match flake inputs
      registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

      # Trim old Nix generations to free up space.
      gc = {
        automatic = true;
        persistent = true;
        dates = "daily";
        options = "--delete-older-than 7d";
      };
    };
  };
}
