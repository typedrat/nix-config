{
  lib,
  stdenv,
  fetchurl,
  jdk8,
  unzrip,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "xmage";
  version = "1.4.56-dev_2025-02-09_16-07";

  src = fetchurl {
    url = "http://xmage.today/files/mage-full_${finalAttrs.version}.zip";
    sha256 = "sha256-zpCUDApYZXHDEjwFOtg+L/5Es4J96F4Z2ojFcrzYumo=";
  };

  preferLocalBuild = true;

  unpackPhase = ''
    ${unzrip}/bin/unzrip $src
  '';

  installPhase = let
    # upstream maintainers forgot to update version, so manual override for now
    # strVersion = lib.substring 0 6 finalAttrs.version;
    strVersion = "1.4.56";
  in ''
    mkdir -p $out/bin
    cp -rv ./* $out

    cat << EOS > $out/bin/xmage
    exec ${jdk8}/bin/java \
        -Xms256m -Xmx1024m -XX:MaxPermSize=384m -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled \
        -Dsun.java2d.opengl=true -Dsun.java2d.opengl.fbobject=false \
        -jar $out/xmage/mage-client/lib/mage-client-${strVersion}.jar
    EOS

    chmod +x $out/bin/xmage
  '';

  meta = with lib; {
    description = "Magic Another Game Engine";
    mainProgram = "xmage";
    sourceProvenance = with sourceTypes; [binaryBytecode];
    license = licenses.mit;
    maintainers = with maintainers; [
      matthiasbeyer
      abueide
    ];
    homepage = "http://xmage.today/";
  };
})
