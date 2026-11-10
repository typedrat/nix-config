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

  catppuccinClaude = pkgs.catppuccin-claude.override {
    inherit (config.catppuccin) accent;
    darkFlavor =
      if config.catppuccin.flavor == "latte"
      then "mocha"
      else config.catppuccin.flavor;
  };

  # Swap the app's entrypoint for one that injects the Catppuccin sheet and
  # then requires the original, rather than patching minified call sites that
  # change every release. Repacking has to keep the official unpacked set (the
  # .node bindings and helper binaries) unpacked and executable.
  claude-desktop = inputs'.claude-desktop-debian.packages.claude-desktop.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [pkgs.jq];

    postInstall =
      old.postInstall
      + ''
        resources=$out/lib/claude-desktop/resources
        work=$(mktemp -d)
        asar extract "$resources/app.asar" "$work/app"

        main=$(jq -r .main "$work/app/package.json")
        substitute ${./claude-desktop-catppuccin.js} "$work/app/catppuccin.js" \
          --replace-fail @main@ "./$main"
        cp ${catppuccinClaude}/catppuccin.css ${catppuccinClaude}/titlebar.json "$work/app/"
        jq '.main = "catppuccin.js"' "$work/app/package.json" > "$work/package.json"
        mv "$work/package.json" "$work/app/package.json"

        (cd "$resources/app.asar.unpacked" && find . -type f | sort) > "$work/unpacked"
        unpack="{$(sed "s|^\./|$work/app/|" "$work/unpacked" | paste -sd,)}"
        mkdir "$work/out"
        asar pack "$work/app" "$work/out/app.asar" --unpack "$unpack"
        diff -r "$resources/app.asar.unpacked" "$work/out/app.asar.unpacked"
        while read -r f; do
          chmod --reference="$resources/app.asar.unpacked/$f" "$work/out/app.asar.unpacked/$f"
        done < "$work/unpacked"

        rm -r "$resources/app.asar" "$resources/app.asar.unpacked"
        mv "$work/out/app.asar" "$work/out/app.asar.unpacked" "$resources/"
        rm -r "$work"
      '';
  });
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/Claude"];
    };

    home.packages = [claude-desktop];
  };
}
