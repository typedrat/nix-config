{inputs, ...}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: {
    apps = let
      nixos-rebuild = pkgs.nixos-rebuild-ng.override {
        nix = inputs.nix.packages.${system}.default;
      };

      mkRebuildApp = action: {
        type = "app";
        program = toString (pkgs.writeShellScript "nixos-rebuild-${action}" ''
          current_host=$(${pkgs.nettools}/bin/hostname)
          target_host=""
          flags=()

          # If first argument doesn't start with -, treat it as hostname
          if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
            target_host="$1"
            shift
            flags=("$@")
          else
            # All arguments are flags
            flags=("$@")
          fi

          # Default to current host if no hostname specified
          if [ -z "$target_host" ]; then
            target_host="$current_host"
          fi

          # Add --target-host if building for a different host
          if [ "$current_host" != "$target_host" ]; then
            flags+=(--target-host "$target_host")
          fi

          ${lib.getExe nixos-rebuild} ${action} \
            --flake .#"$target_host" \
            --log-format internal-json \
            --sudo \
            "''${flags[@]}" \
            |& ${lib.getExe pkgs.nix-output-monitor} --json
        '');
      };
    in {
      switch = mkRebuildApp "switch";
      boot = mkRebuildApp "boot";
    };
  };
}
