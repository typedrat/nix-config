{lib, ...}: let
  inherit (lib) options types;
in {
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./nvidia.nix
    ./openrgb.nix
    ./udisks2.nix
    ./usbmuxd.nix
  ];

  options.rat.hardware.network.mainInterface = options.mkOption {
    type = types.nullOr types.str;
    description = "The main network interface";
    default = null;
  };
}
