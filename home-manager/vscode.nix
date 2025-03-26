{pkgs, ...}: {
  programs.vscode = {
    enable = true;

    profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        jnoortheen.nix-ide
        nrwl.angular-console
      ];
    };
  };
}
