{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username homeDirectory;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};

  hosts = "${pkgs.gstack}/share/gstack-hosts";
  stateDir = "${homeDirectory}/.gstack";

  # host tree -> directory the agent reads it from
  links = {
    "claude/skills" = ".claude/skills";
    "codex/skills" = ".codex/skills";
    "opencode/skills" = ".config/opencode/skills";
    "opencode/commands" = ".config/opencode/commands";
  };
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.ai.enable && osConfig.rat.ai.gstack.enable) {
    # The skill directories share their parents with skills from other
    # sources and their names come from the build, so they are linked one by
    # one here instead of through home.file. Each set of links is recorded in
    # a manifest so that skills dropped upstream are unlinked on the next
    # activation. A real file or directory in the way (an install from
    # gstack's own ./setup) is moved aside, never deleted.
    home.activation.gstack = lib.hm.dag.entryAfter ["writeBoundary"] ''
      manifests=${lib.escapeShellArg stateDir}/nix-links
      backups=${lib.escapeShellArg stateDir}/backups/pre-nix-$(date +%Y%m%d%H%M%S)
      run mkdir -p "$manifests"

      gstackLink() {
        local src=$1 dest=$2 manifest=$3 entry name target
        [ -d "$src" ] || return 0
        run mkdir -p "$dest"

        if [ -f "$manifest" ]; then
          while IFS= read -r name; do
            [ -n "$name" ] && [ ! -e "$src/$name" ] && [ ! -L "$src/$name" ] || continue
            target=$(readlink "$dest/$name" 2>/dev/null) || continue
            case "$target" in /nix/store/*) run rm -f "$dest/$name" ;; esac
          done < "$manifest"
        fi

        for entry in "$src"/*; do
          [ -e "$entry" ] || continue
          name=''${entry##*/}
          if [ -e "$dest/$name" ] && [ ! -L "$dest/$name" ]; then
            run mkdir -p "$backups/''${dest#"$HOME"/}"
            run mv "$dest/$name" "$backups/''${dest#"$HOME"/}/$name"
          fi
          run ln -sfn "$(readlink -f "$entry")" "$dest/$name"
        done

        if [ -z "''${DRY_RUN:-}" ]; then
          (cd "$src" && ls -A) > "$manifest"
        fi
      }

      ${lib.concatStrings (lib.mapAttrsToList (tree: dest: ''
          gstackLink ${hosts}/${tree} ${lib.escapeShellArg "${homeDirectory}/${dest}"} "$manifests/${lib.replaceStrings ["/"] ["-"] tree}"
        '')
        links)}

      # Updates arrive through the flake; gstack's own updater would try to
      # git-pull the read-only store path. The activation PATH has no awk,
      # which gstack-config needs.
      PATH=${lib.makeBinPath [pkgs.gawk]}:$PATH run ${pkgs.gstack}/share/gstack/bin/gstack-config set auto_upgrade false
      PATH=${lib.makeBinPath [pkgs.gawk]}:$PATH run ${pkgs.gstack}/share/gstack/bin/gstack-config set update_check false
    '';
  };
}
