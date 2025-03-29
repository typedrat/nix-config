default:
    @just --list --unsorted

# Switch NixOS to the current state of the configuration flake immediately. Must be run as root!
switch:
    nixos-rebuild switch --flake .#hyperion --log-format internal-json |& nom --json

# Switch NixOS to the current state of the configuration flake on the next boot. Must be run as root!
boot:
    nixos-rebuild boot --flake .#hyperion --log-format internal-json |& nom --json
