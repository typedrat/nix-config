{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  programs.zed-editor = {
    enable = true;
  };

  home.packages = [pkgs.jetbrains.rust-rover];
}
