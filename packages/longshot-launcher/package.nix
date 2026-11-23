{
  lib,
  appimageTools,
  buildFHSEnv,
  fetchurl,
  makeDesktopItem,
  writeShellScript,
  writeShellApplication,
  curl,
  jq,
  gnused,
  coreutils,
}: let
  pname = "longshot-launcher";
  version = "1.2.0";

  src = fetchurl {
    url = "https://git-cdn.magicbean.dev/MagicBeanDev/LongshotLauncher/releases/download/v${version}/LongshotLauncher-v${version}-x86_64.AppImage";
    hash = "sha256-wenmjtfeeIlfXEPG7b7FvCUlTYCyOkb4Vt+ygeWYgzo=";
  };

  contents = appimageTools.extract {inherit pname version src;};

  extraPkgs = pkgs:
    with pkgs; [
      # .NET (Avalonia) runtime of the launcher itself
      icu
      libICE
      libSM
      libX11
      libXcursor
      libXext
      libXfixes
      libXi
      libXrandr
      # The built game
      libdecor
      vulkan-loader
      zstd
    ];

  # Starts an already-built game without the launcher, in the same FHS
  # environment, so it can be a Steam shortcut or a menu entry of its own. The
  # game folder defaults to the launcher's default install location.
  play = buildFHSEnv (appimageTools.defaultFhsEnvArgs
    // {
      pname = "longshot";
      inherit version;
      targetPkgs = pkgs: appimageTools.defaultFhsEnvArgs.targetPkgs pkgs ++ extraPkgs pkgs;
      runScript = writeShellScript "longshot-play" ''
        folder=''${1:-$HOME/Games/Longshot}
        if ! [ -x "$folder/bin/longshot" ]; then
          echo "longshot: no built game in $folder; build one with longshot-launcher first" >&2
          exit 1
        fi
        cd "$folder"
        # Updates are the launcher's job; this mirrors what its Play button sets.
        export LONGSHOT_NO_UPDATE_CHECK=1
        exec ./bin/longshot
      '';
    });

  playDesktopItem = makeDesktopItem {
    name = "longshot";
    desktopName = "Longshot";
    comment = "Play the Longshot build in ~/Games/Longshot";
    exec = "longshot";
    icon = "longshot-launcher";
    categories = ["Game"];
  };
in
  # The launcher downloads the Longshot builder, its prebuilt clang/lld toolchain
  # and finally the compiled game, all of them ordinary glibc binaries. Running
  # the launcher inside the FHS environment is what lets those run unpatched,
  # because they inherit it as child processes.
  appimageTools.wrapType2 {
    inherit pname version src extraPkgs;

    extraInstallCommands = ''
      ln -s ${play}/bin/longshot $out/bin/longshot
      install -Dm444 ${playDesktopItem}/share/applications/longshot.desktop \
        $out/share/applications/longshot.desktop
      install -Dm444 ${contents}/longshot-launcher.desktop $out/share/applications/longshot-launcher.desktop
      substituteInPlace $out/share/applications/longshot-launcher.desktop \
        --replace-fail 'Exec=LongshotLauncher' 'Exec=${pname}'
      install -Dm444 ${contents}/longshot-launcher.png \
        $out/share/icons/hicolor/256x256/apps/longshot-launcher.png
    '';

    passthru.updateScript = lib.getExe (writeShellApplication {
      name = "longshot-launcher-update";
      runtimeInputs = [
        curl
        jq
        gnused
        coreutils
      ];
      text = builtins.readFile ./update.sh;
    });

    meta = {
      description = "Builds and runs Longshot, a static recompilation of a Switch game, from your own copy";
      homepage = "https://longshot.magicbean.dev";
      license = lib.licenses.gpl3Only;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = pname;
      platforms = ["x86_64-linux"];
    };
  }
