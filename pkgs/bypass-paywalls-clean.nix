{
  fetchurl,
  lib,
  stdenv,
} @ args: let
  buildFirefoxXpiAddon = lib.makeOverridable ({
    stdenv ? args.stdenv,
    fetchurl ? args.fetchurl,
    pname,
    version,
    addonId,
    url,
    sha256,
    meta,
    ...
  }:
    stdenv.mkDerivation {
      name = "${pname}-${version}";

      inherit meta;

      src = fetchurl {inherit url sha256;};

      preferLocalBuild = true;
      allowSubstitutes = true;

      passthru = {inherit addonId;};

      buildCommand = ''
        dst="$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
        mkdir -p "$dst"
        install -v -m644 "$src" "$dst/${addonId}.xpi"
      '';
    });

  version = "4.0.7.0";
in
  buildFirefoxXpiAddon {
    pname = "bypass-paywalls-clean";
    inherit version;
    addonId = "magnolia@12.34";
    url = "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass_paywalls_clean-${version}.xpi";
    sha256 = "sha256-feTtEQdxOA2sIu7PB4BsljjwoyN8yIZ9pXrQ/AepyMM=";
    meta = with lib; {
      homepage = "https://twitter.com/Magnolia1234B";
      description = "Bypass Paywalls of (custom) news sites";
      license = licenses.mit;
      platforms = platforms.all;
    };
  }
