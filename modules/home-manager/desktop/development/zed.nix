{
  config,
  osConfig,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # Rebuild fenix's rust-analyzer-nightly against our *patched* nixpkgs so
  # importCargoLock hits static.crates.io instead of crates.io/api/v1 (which
  # now returns 403 without a User-Agent header). fenix's own outputs are
  # evaluated against its bundled nixpkgs follower (the unpatched root input),
  # which still has the broken URL — see flake.nix patches region.
  # Build recipe mirrors fenix/default.nix's `rust-analyzer` attribute.
  rust-analyzer-nightly = let
    nightly = inputs'.fenix.packages.minimal;
    rustPlatform = pkgs.makeRustPlatform {
      inherit (nightly) cargo rustc;
    };
    src = inputs'.fenix.packages.rust-analyzer.src;
    rev = src.rev or "0000000000000000000000000000000000000000";
    date = let
      d = src.lastModifiedDate or "00000000000000";
    in "${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}";
  in
    rustPlatform.buildRustPackage {
      pname = "rust-analyzer-nightly";
      version = rev;
      inherit src;
      cargoLock.lockFile = src + "/Cargo.lock";
      cargoBuildFlags = ["-p" "rust-analyzer"];
      doCheck = false;
      CARGO_INCREMENTAL = 0;
      patchPhase = ''
        mkdir .git/
        echo nightly > .git/HEAD
      '';
      CFG_RELEASE_CHANNEL = "nightly";
      RA_COMMIT_HASH = rev;
      RA_COMMIT_SHORT_HASH = builtins.substring 0 7 rev;
      RA_COMMIT_DATE = date;
      CFG_RELEASE = "0.0.0-nightly";
      meta.mainProgram = "rust-analyzer";
    };
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.development.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/zed" ".local/share/zed"];
    };
    programs.zed-editor = {
      enable = true;

      extraPackages = with pkgs; [
        nixd
        alejandra
        package-version-server
        vscode-langservers-extracted
        rust-analyzer-nightly
        lua-language-server
      ];

      extensions = [
        "astro"
        "authzed"
        "catppuccin"
        "catppuccin-icons"
        "codebook"
        "discord-presence"
        "dockerfile"
        "emmet"
        "env"
        "git-firefly"
        "haskell"
        "helm"
        "html"
        "ini"
        "just"
        "latex"
        "lua"
        "make"
        "mcp-server-context7"
        "neocmake"
        "nix"
        "pkl"
        "python-requirements"
        "scss"
        "sql"
        "tera"
        "terraform"
        "toml"
        "xml"
      ];

      userSettings = {
        languages = {
          Nix = {
            language_servers = ["nixd" "!nil"];

            formatter = {
              external = {
                command = "alejandra";
                arguments = ["--quiet" "--"];
              };
            };
          };
        };

        lsp = {
          package-version-server = {
            binary = {
              path = "package-version-server";
            };
          };
        };

        base_keymap = "VSCode";
        load_direnv = "shell_hook";
        format_on_save = "on";

        theme = lib.mkForce {
          mode = "system";
          light = "Catppuccin Latte (lavender)";
          dark = "Catppuccin Frappé (lavender)";
        };

        icon_theme = lib.mkForce {
          mode = "system";
          light = "Catppuccin Latte";
          dark = "Catppuccin Frappé";
        };

        ui_font_family = builtins.head osConfig.fonts.fontconfig.defaultFonts.sansSerif;
        ui_font_fallbacks = builtins.tail osConfig.fonts.fontconfig.defaultFonts.sansSerif;
        ui_font_size = 13 * (4.0 / 3.0);

        buffer_font_family = builtins.head osConfig.fonts.fontconfig.defaultFonts.monospace;
        buffer_font_fallbacks = builtins.tail osConfig.fonts.fontconfig.defaultFonts.monospace;
        buffer_font_size = 14 * (4.0 / 3.0);
      };
    };

    systemd.user.sessionVariables = {
      EDITOR = "${lib.getExe config.programs.zed-editor.package} -w";
    };
  };
}
