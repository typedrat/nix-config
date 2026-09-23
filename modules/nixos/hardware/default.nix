{lib, ...}: let
  inherit (lib) options types;
in {
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./esp32-dev.nix
    ./midi.nix
    ./mt7927.nix
    ./nintendo-switch.nix
    ./nvidia.nix
    ./openrgb.nix
    ./printing.nix
    ./scanning.nix
    ./security-key.nix
    ./topping-e2x2.nix
    ./udisks2.nix
    ./usbmuxd.nix
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

    gpu = {
      vendor = options.mkOption {
        type = let
          vendorEnum = types.enum ["nvidia" "amd" "intel"];
        in
          types.either vendorEnum (types.listOf vendorEnum);
        description = "GPU vendor(s)";
        example = "nvidia";
      };

      vram = options.mkOption {
        type = types.ints.positive;
        description = "GPU VRAM in gigabytes";
        example = 16;
      };

      cudaArchitectures = options.mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = ''
          CUDA compute capabilities of this host's NVIDIA GPU(s), spelled the
          way CMAKE_CUDA_ARCHITECTURES wants them.

          The nixpkgs default covers every capability the CUDA release
          supports, which compiles each kernel once per entry and still leaves
          out anything older than the oldest entry. Naming the cards actually
          present builds far less and builds the right thing.
        '';
        example = ["120"];
      };
    };

    network.mainInterface = options.mkOption {
      type = types.nullOr types.str;
      description = "The main network interface";
      default = null;
    };
  };
}
