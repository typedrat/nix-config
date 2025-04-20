{
  pkgs,
  lib,
  ...
}: {
  programs.goldwarden = {
    enable = true;
  };

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.symlinkJoin {
      name = "pinentry-rofi-wrapper";

      paths = [
        pkgs.pinentry-rofi
        (pkgs.writeShellScriptBin "pinentry" "exec -a $0 ${lib.getExe' pkgs.pinentry-rofi "pinentry-rofi"} $@")
      ];

      meta = {
        mainProgram = "pinentry";
      };
    };
  };
}
