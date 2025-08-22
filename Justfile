default:
  @just --list --unsorted

# Switch NixOS to the current state of the configuration flake immediately.
switch:
  nixos-rebuild switch --flake .#hyperion --log-format internal-json --sudo |& nom --json

# Switch NixOS to the current state of the configuration flake on the next boot.
boot:
  nixos-rebuild boot --flake .#hyperion --log-format internal-json --sudo |& nom --json

switch-iserlohn:
  nixos-rebuild switch --flake .#iserlohn --log-format internal-json --target-host iserlohn --sudo |& nom --json

boot-iserlohn:
  nixos-rebuild boot --flake .#iserlohn --log-format internal-json --target-host iserlohn --sudo |& nom --json
