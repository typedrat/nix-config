# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Note for Claude Code**: When making significant changes to the repository structure, build commands, module organization, service architecture, or flake inputs, update this file to keep it accurate and helpful.

## System Architecture

This is a NixOS configuration flake using `flake-parts` with a custom `nixos-hosts` module for modular system definitions. The configuration supports two main systems:

- `hyperion`: Local desktop system
- `iserlohn`: Remote server system

### Key Architecture Components

- **Flake Structure**: Uses `flake-parts` for modular flake organization with a custom nixos-hosts module (`modules/extra/flake-parts/nixos-hosts.nix`)
- **Module System**: Organized into multiple categories:
  - `modules/nixos/` - NixOS system modules (boot, games, gui, hardware, security, services, theming, virtualisation)
  - `modules/home-manager/` - Home Manager user modules
  - `modules/shared/` - Shared modules across systems
  - `modules/extra/` - Extra modules for flake-parts integration
- **User Configuration**: Home Manager integration with user-specific configs in `users/`
- **Secrets Management**: SOPS-nix for encrypted secrets stored in `secrets/`
- **Custom Packages**: Local package definitions in `pkgs/` directory with automatic discovery via `pkgs-by-name-for-flake-parts`
- **Terraform Integration**: Infrastructure as code with `terranix` module for service configuration

### Service Architecture

The server (`iserlohn`) runs a comprehensive media, development, and home automation stack:

- **Core Services**: Traefik reverse proxy, Authentik SSO (with LDAP), PostgreSQL/MySQL databases, ACME/Let's Encrypt
- **Media Stack**:
  - Streaming: Jellyfin
  - Content management: Sonarr/Sonarr-Anime, Radarr/Radarr-Anime, Lidarr, Prowlarr, Shoko
  - Download: qBittorrent, autobrr, cross-seed
  - Configuration: configarr
- **Development**:
  - Attic binary cache
  - GitHub Actions runner
  - Hydra CI (available but not currently enabled)
- **Monitoring**: Grafana, Prometheus, Loki with custom exporters (exportarr, authentik, traefik, qbittorrent, ipmi, postgres, node, zfs)
- **Communication**:
  - Matrix (Synapse) with Element web client
  - Heisenbridge IRC bridge
  - SillyTavern AI chat interface
- **Home Automation**: Home Assistant with MQTT support (Mosquitto)

## Common Development Commands

### System Management

```bash
# Local system rebuild (current host or hyperion)
nix run .#switch
nix run .#switch hyperion

# Remote system rebuild (iserlohn)
nix run .#switch iserlohn

# Build on iserlohn (recommended for faster builds)
# Use -- to pass flags to the script, not to nix run
nix run .#switch -- --build-host iserlohn
nix run .#switch hyperion -- --build-host iserlohn

# Boot-time configuration changes (safer than immediate switch)
nix run .#boot
nix run .#boot iserlohn

# Pass additional flags to nixos-rebuild
nix run .#switch -- --show-trace
nix run .#switch iserlohn -- --show-trace --build-host iserlohn
```

The rebuild apps automatically:
- Detect the current hostname if none is provided
- Add `--target-host` for remote builds
- Use `nix-output-monitor` for prettier build output
- Use Determinate Systems Nix with the new experimental CLI

**Tip**: Use `--build-host iserlohn` to offload builds to the remote server, which is often faster than building locally. Remember to use `--` before the flag to pass it to nixos-rebuild rather than `nix run`.

### Code Formatting and Linting

```bash
# Format all Nix code (uses alejandra, deadnix, statix via treefmt)
nix fmt

# Build specific outputs
nix build .#<package-name>

# Build a specific system configuration
nix build .#nixosConfigurations.hyperion.config.system.build.toplevel
nix build .#nixosConfigurations.iserlohn.config.system.build.toplevel
```

### Terraform Infrastructure

```bash
# Use terranix wrapper from repository root
# The wrapper automatically sets up SSH tunnels and environment variables
nix run .#terraform.wrapper -- plan
nix run .#terraform.wrapper -- apply

# Or navigate to terraform directory
cd terraform
# The terraform config is symlinked from the nix store
```

The terranix wrapper automatically:
- Decrypts required secrets from `secrets/default.yaml` using SOPS
- Sets up SSH tunnels to iserlohn for service management (Lidarr, Prowlarr, Radarr, Sonarr, etc.)
- Exports B2 credentials for backend state storage
- Cleans up SSH connections on exit

## Key File Locations

- **System configs**: `systems/{hyperion,iserlohn}/`
- **NixOS modules**: `modules/nixos/`
- **User configs**: `users/awilliams/`
- **Custom packages**: `pkgs/`
- **Secrets**: `secrets/` (SOPS encrypted)
- **Terraform**: `terraform/` (uses terranix)

## Important Patterns

### Module Organization

- Each service/component has its own module file
- Default imports are handled in `default.nix` files within each category
- Services are logically grouped in `modules/nixos/services/`:
  - `core/` - Essential services (Traefik, Authentik, databases, monitoring)
  - `media/` - Media management and streaming services
  - `development/` - Development tools and CI/CD
  - `communication/` - Matrix and chat services
  - `home/` - Home Assistant and IoT
  - `monitoring/` - Grafana, Prometheus, Loki, and exporters
- NixOS modules use `rat.*` namespace for configuration options
- Home Manager modules are separate in `modules/home-manager/`

### Secret Management

- All secrets use SOPS encryption stored in `secrets/`
- Reference secrets in configurations using `config.sops.secrets.<name>.path`
- Never commit unencrypted secrets
- SOPS configuration is in `modules/nixos/sops.nix`
- Terraform secrets are decrypted by the terranix wrapper at runtime

### Custom Package Development

- Add new packages to `pkgs/` directory
- `pkgs-by-name-for-flake-parts` provides automatic package discovery
- Packages are automatically available as `pkgs.<name>` after being added
- Follow existing package patterns for consistency
- Custom package overlays are available for more complex modifications

### Terraform Service Configuration

- Infrastructure definitions in `terraform/` using terranix
- Automatically integrates with NixOS configuration via `config.links` for service discovery
- Uses SSH tunneling for secure remote management to services not exposed publicly
- Terraform state is stored in Backblaze B2
- Service configurations in `terraform/arrs/` and `terraform/authentik/`

### NixOS Configuration Patterns

- System-specific configurations in `systems/{hyperion,iserlohn}/default.nix`
- Use `lib.mkAfter` and `lib.mkBefore` for careful ordering of lists
- Hardware-specific modules: Disko for disk partitioning, ZFS management, Lanzaboote for Secure Boot
- TPM2 integration for system identity and secret unsealing
- Impermanence enabled on iserlohn with ZFS for ephemeral root

## Key Flake Inputs

The configuration uses several important flake inputs:

- **Core Inputs**:
  - `nixpkgs` - Main package repository (unstable channel)
  - `nixpkgs-stable` - Stable channel (25.05) for specific packages
  - `determinate` - Determinate Systems Nix for improved CLI and features
  - `home-manager` - User environment management
  - `flake-parts` - Modular flake organization
  - `sops-nix` - Secrets management

- **NixOS Extensions**:
  - `lanzaboote` - Secure Boot support
  - `disko` - Declarative disk partitioning
  - `impermanence` - Ephemeral root filesystem support
  - `microvm` - MicroVM virtualization
  - `nixvirt` - Libvirt/KVM declarative configuration
  - `nixos-wsl` - WSL support (available but not currently used)

- **Theming**:
  - `catppuccin` - Catppuccin theme integration
  - `spicetify-nix` - Spotify theming
  - `apple-fonts` / `apple-emoji` - Apple fonts and emoji
  - Various Catppuccin themes for specific applications

- **Desktop Environment**:
  - `hyprland` - Wayland compositor
  - `hyprlock` - Screen locker
  - `hyprland-plugins` - Additional Hyprland functionality
  - `pyprland` - Hyprland extensions in Python

- **External Software**:
  - `attic` - Binary cache server
  - `authentik-nix` - Authentik SSO
  - `anime-game-launcher` - Game launcher
  - `zen-browser` - Zen browser
  - `talhelper` - Talos Kubernetes helper

- **Development Tools**:
  - `terranix` - Terraform configuration in Nix
  - `treefmt-nix` - Code formatting
  - `fenix` - Rust toolchain management
  - `pkgs-by-name-for-flake-parts` - Automatic package discovery

## Testing Changes

Always test system changes safely:

1. Use `nix run .#boot` for boot-time testing rather than immediate switch
2. Test package builds with `nix build .#<package>` before system rebuild
3. Verify formatting with `nix fmt` before commits
4. For remote systems (iserlohn), ensure SSH access before deploying changes
5. Check `nix flake check` for basic validation (may take a while)
6. Use `--show-trace` flag for debugging evaluation errors

## Additional Notes

- Both systems use ZFS with the `rpool` pool name
- The configuration uses Catppuccin theming extensively across applications
- Custom fonts include Apple SF Pro, SF Mono, and New York
- The `rat.*` namespace is used for custom NixOS options throughout the configuration
- Nixpkgs patches can be added via inputs prefixed with `nixpkgs-patch-` (handled by nixpkgs-patcher)
