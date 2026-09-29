{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  developmentCfg = guiCfg.development or {};
in {
  imports = [
    ./ghidra.nix
    ./imhex.nix
    ./vscode.nix
    ./zed.nix
  ];

  config = modules.mkIf (guiCfg.enable && developmentCfg.enable) {
    home.packages = with pkgs; [
      virt-manager

      # Its launcher appends a plain perf to PATH, which would record without
      # the capabilities that kernel profiling needs.
      (hotspot.override {perf = osConfig.rat.security.perf.wrap perf;})
    ];
  };
}
