{
  config,
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  themingCfg = userCfg.theming or {};
  guiCfg = userCfg.gui or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  capitalizeFirst = str:
    (lib.toUpper (builtins.substring 0 1 str)) + (builtins.substring 1 (builtins.stringLength str) str);

  # Parse a KDE .colors INI file into an attrset of { "Section" = { Key = "value"; }; }
  # Handles duplicate keys (last wins, matching KDE behavior) and blank/comment lines.
  parseKdeColorScheme = path: let
    content = builtins.readFile path;
    lines = builtins.filter (l: l != "") (lib.splitString "\n" content);

    # Split a string on the first occurrence of "="
    splitFirst = sep: str: let
      parts = lib.splitString sep str;
    in
      if builtins.length parts < 2
      then null
      else {
        key = lib.trim (builtins.head parts);
        value = lib.trim (builtins.concatStringsSep sep (builtins.tail parts));
      };

    # Fold over lines, accumulating { currentSection, result }
    parsed =
      builtins.foldl'
      (
        acc: line: let
          trimmed = lib.trim line;
          isSectionHeader = lib.hasPrefix "[" trimmed && lib.hasSuffix "]" trimmed;
          sectionName = builtins.substring 1 (builtins.stringLength trimmed - 2) trimmed;
          isComment = lib.hasPrefix "#" trimmed;
          isBlank = trimmed == "";
          kv = splitFirst "=" trimmed;
        in
          if isBlank || isComment
          then acc
          else if isSectionHeader
          then acc // {currentSection = sectionName;}
          else if kv != null && acc.currentSection != null
          then let
            existing = acc.result.${acc.currentSection} or {};
          in
            acc
            // {
              result =
                acc.result
                // {
                  ${acc.currentSection} =
                    existing
                    // {
                      ${kv.key} = kv.value;
                    };
                };
            }
          else acc
      )
      {
        currentSection = null;
        result = {};
      }
      lines;
  in
    parsed.result;

  catppuccinKde = pkgs.catppuccin-kde.override {
    flavour = [config.catppuccin.flavor];
    accents = [config.catppuccin.accent];
    winDecStyles = ["modern"];
  };

  colorSchemeName = "Catppuccin${capitalizeFirst config.catppuccin.flavor}${capitalizeFirst config.catppuccin.accent}";
  colorSchemeFile = "${catppuccinKde}/share/color-schemes/${colorSchemeName}.colors";
  colorSchemeData = parseKdeColorScheme colorSchemeFile;
in {
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    inputs.plasma-manager.homeModules.plasma-manager

    ./steam.nix
  ];

  config = modules.mkIf themingCfg.enable (
    modules.mkMerge [
      {
        home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
          directories = [".config/dconf"];
        };

        catppuccin = {
          enable = true;
          inherit (osConfig.catppuccin) flavor;
          inherit (osConfig.catppuccin) accent;
        };
      }

      (modules.mkIf guiCfg.enable {
        catppuccin = {
          gtk.icon.enable = true;
          cursors.enable = true;
          kvantum.enable = true;
          waybar.mode = "createLink";
        };

        gtk = {
          enable = true;

          font = {
            name = "SF Pro Display";
            size = 13;
          };

          theme = {
            package = pkgs.adw-gtk3;
            name = "adw-gtk3-dark";
          };

          gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
          gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
          gtk3.extraCss = builtins.readFile ./gtk3/gtk.css;
          gtk4.extraCss = builtins.readFile ./gtk4/gtk.css;
        };

        xdg.configFile."gtk-4.0/colors.css".source = ./gtk4/colors.css;

        dconf = {
          enable = true;
          settings = {
            "org/gnome/desktop/interface" = {
              color-scheme = "prefer-dark";
            };

            "org/gnome/desktop/wm/preferences" = {
              button-layout = "";
            };
          };
        };

        qt = {
          enable = true;
          platformTheme.name = "kvantum";
          style.name = "kvantum";
        };

        # KDE color scheme: write color values directly into kdeglobals via
        # plasma-manager's configFile, rather than relying on plasma-apply-colorscheme
        # at runtime (which silently no-ops under Hyprland without a Plasma session).
        programs.plasma.configFile.kdeglobals = colorSchemeData;

        home.packages = [catppuccinKde];
      })
    ]
  );
}
