{pkgs, ...}: {
  imports = [
    ./jetbrains.nix
    ./vscode.nix
    ./zed.nix
  ];

  home.packages = with pkgs; [
    virt-manager-qt
  ];
}
