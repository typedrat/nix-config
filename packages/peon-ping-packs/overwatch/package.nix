{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}: let
  src = fetchFromGitHub {
    owner = "heron--";
    repo = "overwatch-peon-pings";
    rev = "c4505f45fe02828b98b56b83f403f4edfa43ac30";
    hash = "sha256-3cj7bH/rpM9srhLwhLa90dM8EnFdJslFMFcVxol6Dps=";
  };

  version = "0-unstable-2025-03-29";

  characters = [
    "ana"
    "ashe"
    "baptiste"
    "bastion"
    "brigitte"
    "cassidy"
    "domina"
    "doomfist"
    "echo"
    "emre"
    "freja"
    "genji"
    "hanzo"
    "hazard"
    "illari"
    "jetpack_cat"
    "junker_queen"
    "junkrat"
    "juno"
    "lifeweaver"
    "lucio"
    "mauga"
    "mei"
    "mercy"
    "mizuki"
    "moira"
    "orisa"
    "pharah"
    "ramattra"
    "reaper"
    "reinhardt"
    "roadhog"
    "sigma"
    "sojourn"
    "soldier_76"
    "sombra"
    "symmetra"
    "torbjorn"
    "tracer"
    "vendetta"
    "venture"
    "widowmaker"
    "winston"
    "zarya"
    "zenyatta"
  ];

  _repo = stdenvNoCC.mkDerivation {
    pname = "peon-ping-packs-overwatch";
    inherit version src;

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      cp -r . $out
      runHook postInstall
    '';

    passthru.updateScript = nix-update-script {extraArgs = ["--flake" "--version=branch"];};

    meta = {
      description = "Overwatch sound packs for peon-ping";
      homepage = "https://github.com/heron--/overwatch-peon-pings";
      platforms = lib.platforms.all;
    };
  };

  mkPack = name:
    stdenvNoCC.mkDerivation {
      pname = "peon-ping-pack-overwatch-${name}";
      inherit version;

      dontUnpack = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        cp -r ${_repo}/${name} $out
        runHook postInstall
      '';

      meta = {
        description = "Overwatch ${name} sound pack for peon-ping";
        homepage = "https://github.com/heron--/overwatch-peon-pings";
        platforms = lib.platforms.all;
      };
    };
in
  lib.recurseIntoAttrs (lib.genAttrs characters mkPack // {inherit _repo;})
