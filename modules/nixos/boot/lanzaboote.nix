{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.boot;
in {
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  config = modules.mkIf (cfg.loader == "lanzaboote") {
    boot.lanzaboote = {
      enable = true;
      inherit (cfg.secureBoot) pkiBundle;

      # The signed stub per generation is tiny, but each one pins a kernel and
      # initrd in EFI/nixos -- about 60MB together, against a 1GB ESP.
      # Unlimited (the upstream default) is only safe while garbage collection
      # keeps up, and it does not: the installer writes every generation
      # before it collects, so once the ESP fills the install fails on the
      # write and never reaches the sweep that would have freed the room. That
      # state needs deleting files by hand to escape, so the ceiling is set
      # well under what fits rather than close to it.
      configurationLimit = 5;

      autoEnrollKeys = {
        enable = cfg.secureBoot.autoEnrollKeys;
      };
    };
  };
}
