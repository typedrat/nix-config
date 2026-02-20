{lib, ...}: let
  inherit (lib) options types;
in {
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./nvidia.nix
    ./openrgb.nix
    ./printing.nix
    ./security-key.nix
    ./topping-e2x2.nix
    ./udisks2.nix
    ./usbmuxd.nix
    ./wifi.nix
  ];

  options.rat.hardware = {
    cpu = {
      cores = options.mkOption {
        type = types.ints.positive;
        description = "Number of physical CPU cores";
        example = 8;
      };

      threads = options.mkOption {
        type = types.ints.positive;
        description = "Number of CPU threads (including SMT/hyperthreading)";
        example = 16;
      };
    };

    network.mainInterface = options.mkOption {
      type = types.nullOr types.str;
      description = "The main network interface";
      default = null;
    };
  };
}
