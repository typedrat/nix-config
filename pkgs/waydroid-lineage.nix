{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation {
  pname = "waydroid-lineage";
  version = "18.1-20250301";

  srcs = [
    (fetchurl
      {
        url = "mirror://sourceforge/project/waydroid/images/vendor/waydroid_x86_64/lineage-18.1-20250301-MAINLINE-waydroid_x86_64-vendor.zip";
        hash = "sha256-71K4VeC0PwO5tXfgJ/4uyPKyl34MraEawy79sNKlr8g=";
      })
    (fetchurl
      {
        url = "mirror://sourceforge/project/waydroid/images/system/lineage/waydroid_x86_64/lineage-18.1-20250301-VANILLA-waydroid_x86_64-system.zip";
        hash = "sha256-ZQFYdEIN0ZT924N4L5FR850AC3feQ9FJi16ZFSX7uSk=";
      })
  ];

  nativeBuildInputs = [unzip];

  sourceRoot = ".";

  dontFixup = true;
  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out vendor.img system.img
    runHook postInstall
  '';

  meta = with lib; {
    description = "Waydroid vendor and system images for x86_64";
    homepage = "https://waydro.id/";
    platforms = platforms.x86_64;
  };
}
