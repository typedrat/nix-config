{lib, ...}: let
  inherit (lib) options types;

  guiOptions = types.submodule {
    options = {
      enable = options.mkEnableOption "GUI applications and configuration";

      hyprland = {
        enable = options.mkEnableOption "Hyprland window manager configuration" // {default = true;};
      };

      chat = {
        enable = options.mkEnableOption "chat clients" // {default = true;};
        discord.enable = options.mkEnableOption "Discord" // {default = true;};
        element.enable = options.mkEnableOption "Element (Matrix)" // {default = true;};
      };

      devtools = {
        enable = options.mkEnableOption "graphical development tools" // {default = true;};
        vscode.enable = options.mkEnableOption "VS Code" // {default = true;};
        zed.enable = options.mkEnableOption "Zed editor" // {default = true;};
        imhex.enable = options.mkEnableOption "ImHex" // {default = true;};
      };

      games = {
        enable = options.mkEnableOption "gaming applications" // {default = true;};
        xmage.enable = options.mkEnableOption "XMage" // {default = true;};
        sgdboop.enable = options.mkEnableOption "SGDBoop" // {default = true;};
      };

      media = {
        enable = options.mkEnableOption "media software" // {default = true;};
        spotify.enable = options.mkEnableOption "Spotify" // {default = true;};
        tauon.enable = options.mkEnableOption "Tauon Music Box" // {default = true;};
        mpv.enable = options.mkEnableOption "MPV" // {default = true;};
      };

      productivity = {
        enable = options.mkEnableOption "productivity software" // {default = true;};
        thunderbird.enable = options.mkEnableOption "Thunderbird" // {default = true;};
        obsidian.enable = options.mkEnableOption "Obsidian" // {default = true;};
        libreoffice.enable = options.mkEnableOption "LibreOffice" // {default = true;};
        sioyek.enable = options.mkEnableOption "Sioyek PDF reader" // {default = true;};
        kicad.enable = options.mkEnableOption "KiCad" // {default = true;};
        freecad.enable = options.mkEnableOption "FreeCAD" // {default = true;};
        printing3d.enable = options.mkEnableOption "3D printing tools" // {default = true;};
      };

      browsers = {
        firefox.enable = options.mkEnableOption "Firefox" // {default = true;};
        chromium.enable = options.mkEnableOption "Chromium" // {default = true;};
        zen.enable = options.mkEnableOption "Zen Browser" // {default = true;};
      };

      terminal = {
        wezterm.enable = options.mkEnableOption "WezTerm" // {default = true;};
      };

      easyeffects = {
        enable = options.mkEnableOption "EasyEffects audio processing" // {default = true;};
      };

      packages = {
        enable = options.mkEnableOption "miscellaneous GUI packages" // {default = true;};
      };

      graphics = {
        enable = options.mkEnableOption "graphics and image editing tools" // {default = true;};
      };

      utilities = {
        enable = options.mkEnableOption "general GUI utilities" // {default = true;};
      };

      security = {
        enable = options.mkEnableOption "security applications" // {default = true;};
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.gui = options.mkOption {
        type = guiOptions;
        default = {};
        description = "GUI application configuration options";
      };
    });
  };
}
