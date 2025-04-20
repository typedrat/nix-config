{
  lib,
  stdenv,
  fetchurl,
  jdk8,
  unzrip,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "xmage";
  version = "1.4.57-dev_2025-04-11_13-57";

  src = fetchurl {
    url = "https://xmage.today/files/mage-full_${finalAttrs.version}.zip";
    sha256 = "sha256-yPNeVXU6aXPResIZHC5/eYlxXZh4nGif1jrrgyqxF+Y=";
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
    homepage = "https://xmage.today/";
  };
})
