{
  appimageTools,
  fetchurl,
}: let
  pname = "fontbase";
  version = "2.21.0";

  src = fetchurl {
    url = "https://releases.fontba.se/linux/FontBase-${version}.AppImage";
    hash = "sha256-kmIokW6Yg4oYq9g9EmNrS1SKs0GCqO4xcnt6iwnlw2A=";
  };
in
  appimageTools.wrapType2 {
    inherit pname version src;
  }
