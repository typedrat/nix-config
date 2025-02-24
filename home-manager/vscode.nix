{pkgs, ...}: {
  home.packages = with pkgs; [
    nixd
    alejandra
  ];

  programs.vscode = {
    enable = true;

    userSettings = {
      "editor.formatOnSave" = true;
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nixd";
      "nix.serverSettings" = {
        "nixd" = {
          "formatting" = {
            "command" = ["alejandra"];
          };
        };
      };
    };

    mutableExtensionsDir = false;
    extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      jnoortheen.nix-ide
      mkhl.direnv
      rust-lang.rust-analyzer
      tamasfe.even-better-toml
    ];
  };
}
