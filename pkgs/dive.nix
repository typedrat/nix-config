{
  appimageTools,
  fetchurl,
}: let
  pname = "Dive";
  version = "0.8.8";

  src = fetchurl {
    url = "https://github.com/OpenAgentPlatform/Dive/releases/download/v${version}/Dive-${version}-linux-x86_64.AppImage";
    hash = "sha256-dIPPosqrRoAaXwQ0iaATSnSLpCH0iKA3F88nO+7So1s=";
  };
in
  appimageTools.wrapType2 {
    inherit pname version src;
    extraPkgs = pkgs:
      with pkgs; [
        python3
        uv
        nodejs
        corepack
      ];
  }
