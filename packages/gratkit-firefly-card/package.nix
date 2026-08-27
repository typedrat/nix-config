{
  lib,
  stdenvNoCC,
}: let
  source = ./gratkit-firefly-card.js;
in
  stdenvNoCC.mkDerivation {
    pname = "gratkit-firefly-card";

    # The Home Assistant module appends this to the resource URL as a query
    # string. Deriving it from the file's own hash means an edited card always
    # gets a new URL, so browsers cannot serve a stale copy from cache.
    version = "1.0.0-${builtins.substring 0 8 (builtins.hashFile "sha256" source)}";

    src = source;

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp $src $out/gratkit-firefly-card.js

      runHook postInstall
    '';

    meta = {
      description = "Lovelace card for the GratKit Firefly V2 filament dryer";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
