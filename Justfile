default:
  @just --list --unsorted

# Switch NixOS to the current state of the configuration flake immediately.
switch:
  sudo zsh -c "nixos-rebuild switch --flake .#hyperion --log-format internal-json |& nom --json"

# Switch NixOS to the current state of the configuration flake on the next boot.
boot:
  sudo zsh -c "nixos-rebuild boot --flake .#hyperion --log-format internal-json |& nom --json"

switch-iserlohn:
  nixos-rebuild switch --flake .#iserlohn --log-format internal-json --target-host iserlohn --sudo |& nom --json

boot-iserlohn:
  nixos-rebuild boot --flake .#iserlohn --log-format internal-json --target-host iserlohn --sudo |& nom --json
