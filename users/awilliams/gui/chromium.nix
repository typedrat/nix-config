{
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf osConfig.rat.gui.enable {
    programs.chromium = {
      enable = true;
      commandLineArgs = [
        "-no-default-browser-check"
      ];
      extensions = [
        "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
        "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
        "mbniclmhobmnbdlbpiphghaielnnpgdp" # Lightshot
        "gcbommkclmclpchllfjekcdonpmejbdp" # HTTPS Everywhere
        "lnjaiaapbakfhlbjenjkhffcdpoompki" # Catppuccin for Web File Explorer Icons
        "fmkadmapgofadopljbjfkapdkoienihi" # React Developer Tools
      ];
    };
  };
}
