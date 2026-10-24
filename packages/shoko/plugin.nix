# A first-party Shoko plugin from its release archive, laid out as
# lib/<pname>/ for services.shoko.plugins.
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  # The plugin's source.json: repo, name, version, archive url and hash, and
  # the images to ship.
  source,
  # Extra image names to ship as copies of one of `source.images`, for images
  # the plugin registers under more than one name.
  imageAliases ? {},
  updateScript,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "shoko-plugin-${lib.toLower (lib.removePrefix "Shoko.Plugin." source.repo)}";
  inherit (source) version;

  src = fetchurl {inherit (source) url hash;};

  nativeBuildInputs = [unzip];

  dontUnpack = true;

  # Shoko extracts a plugin's embedded images into its directory on startup
  # unless a file of that name is already there, and the write fails in the
  # store, so the images ship alongside the assemblies.
  installPhase = let
    dir = "$out/lib/${finalAttrs.pname}";
  in ''
    runHook preInstall

    mkdir -p ${dir}
    unzip -q $src -d ${dir}
    ${lib.concatStrings (lib.mapAttrsToList (kind: image: ''
        cp ${fetchurl {inherit (image) url hash;}} ${dir}/${kind}.svg
      '')
      source.images)}
    ${lib.concatStrings (lib.mapAttrsToList (alias: kind: ''
        cp ${dir}/${kind}.svg ${dir}/${alias}.svg
      '')
      imageAliases)}

    runHook postInstall
  '';

  passthru = {inherit updateScript;};

  meta = {
    description = "${source.name} plugin for Shoko Server";
    homepage = "https://github.com/ShokoAnime/${source.repo}";
    changelog = "https://github.com/ShokoAnime/${source.repo}/releases/tag/v${source.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
