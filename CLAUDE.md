# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Architecture

This is a NixOS configuration flake using `flake-parts` and `easy-hosts` for modular system definitions. The configuration supports two main systems:

- `hyperion`: Local desktop system
- `iserlohn`: Remote server system

### Key Architecture Components

- **Flake Structure**: Uses `flake-parts` for modular flake organization with system-specific configurations
- **Module System**: Organized into logical categories (gui, hardware, security, services, etc.) under `modules/nixos/`
- **User Configuration**: Home Manager integration with user-specific configs in `users/`
- **Secrets Management**: SOPS-nix for encrypted secrets stored in `secrets/`
- **Custom Packages**: Local package definitions in `pkgs/` directory
- **Terraform Integration**: Infrastructure as code with `terranix` module for service configuration

### Service Architecture

The server (`iserlohn`) runs a comprehensive media and development stack:

- **Core Services**: Traefik reverse proxy, Authentik SSO, PostgreSQL/MySQL databases
- **Media Stack**: Jellyfin, Sonarr/Radarr/Lidarr, qBittorrent, Prowlarr
- **Development**: Attic binary cache, various development tools
- **Monitoring**: Grafana, Prometheus, Loki with custom exporters
- **Communication**: Matrix (Synapse), Element, Discord bridges

## Common Development Commands

### System Management

```bash
# Local system rebuild (hyperion)
just switch

# Remote system rebuild (iserlohn)
just switch-iserlohn

# Boot-time configuration changes
just boot
just boot-iserlohn
```

### Code Formatting and Linting

```bash
# Format all Nix code (uses alejandra, deadnix, statix)
nix fmt

# Build specific outputs
nix build .#<package-name>
```

### Terraform Infrastructure

```bash
# Navigate to terraform directory and use terranix wrapper
cd terraform
# The terranix wrapper automatically sets up SSH tunnels and environment variables
nix run .#terraform.wrapper -- plan
nix run .#terraform.wrapper -- apply
```

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
- Default imports are handled in `default.nix` files
- Services are logically grouped (core, media, development, etc.)

### Secret Management

- All secrets use SOPS encryption
- Reference secrets in configurations using `config.sops.secrets.<name>.path`
- Never commit unencrypted secrets

### Custom Package Development

- Add new packages to `pkgs/` directory
- Use `pkgs-by-name-for-flake-parts` for automatic package discovery
- Follow existing package patterns for consistency

### Terraform Service Configuration

- Infrastructure definitions in `terraform/`
- Automatically integrates with NixOS configuration for service discovery
- Uses SSH tunneling for secure remote management

## Testing Changes

Always test system changes safely:

1. Use `just boot` for boot-time testing rather than immediate switch
2. Test package builds with `nix build .#<package>`
3. Verify formatting with `nix fmt` before commits
4. For remote systems, ensure SSH access before deploying changes
