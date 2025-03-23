{
  pkgs,
  config,
  ...
}: let
  catppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "process-compose";
    rev = "b0c48aa07244a8ed6a7d339a9b9265a3b561464d";
    hash = "sha256-uqJR9OPrlbFVnWvI3vR8iZZyPSD3heI3Eky4aFdT0Qo=";
  };
in {
  home.packages = with pkgs; [
    process-compose
  ];

  xdg.configFile."process-compose/theme.yaml".source = "${catppuccin}/themes/catppuccin-${config.catppuccin.flavor}.yaml";
}
