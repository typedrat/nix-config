{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf;
in {
  imports = [
    ./imhex.nix
    ./vscode.nix
    ./zed.nix
  ];

  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.devtools.enable) {
    home.packages = with pkgs; [
      virt-manager
    ];
  };
}
