{
  lib,
  buildDotnetModule,
  fetchFromGitHub,
  dotnet-sdk_10,
  dotnet-runtime_10,
  copyDesktopItems,
  makeDesktopItem,
  libusb1,
  libx11,
  libice,
  libsm,
  libxi,
  libxcursor,
  libxext,
  libxrandr,
  fontconfig,
  nix-update-script,
}:
buildDotnetModule (finalAttrs: {
  pname = "omnircm";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "DefenderOfHyrule";
    repo = "OmniRCM";
    tag = "v${finalAttrs.version}";
    hash = "sha256-u3xeBibPUTepAl3SZpuSI2s4y8pU60zlMCO5p7FHzMQ=";
  };

  # The updater replaces the running executable with a downloaded release,
  # which can only fail in the store.
  postPatch = ''
    substituteInPlace MainWindow.axaml.cs \
      --replace-fail \
        'var info = await UpdateChecker.CheckAsync(CurrentVersion);' \
        'UpdateChecker.UpdateInfo? info = null;'
  '';

  dotnet-sdk = dotnet-sdk_10;
  dotnet-runtime = dotnet-runtime_10;

  projectFile = "OmniRCM.csproj";
  nugetDeps = ./deps.json;
  executables = ["OmniRCM"];

  nativeBuildInputs = [copyDesktopItems];

  runtimeDeps = [
    libusb1
    libx11
    libice
    libsm
    libxi
    libxcursor
    libxext
    libxrandr
    fontconfig
  ];

  postInstall = ''
    install -Dm444 Assets/icon.png $out/share/pixmaps/omnircm.png
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "omnircm";
      desktopName = "OmniRCM";
      comment = finalAttrs.meta.description;
      exec = "OmniRCM";
      icon = "omnircm";
      categories = ["Utility"];
    })
  ];

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Nintendo Switch RCM payload injector";
    homepage = "https://github.com/DefenderOfHyrule/OmniRCM";
    changelog = "https://github.com/DefenderOfHyrule/OmniRCM/releases/tag/v${finalAttrs.version}";
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      # SkiaSharp and HarfBuzzSharp ship prebuilt in their NuGet packages
      binaryNativeCode
    ];
    license = lib.licenses.gpl3Only;
    mainProgram = "OmniRCM";
    platforms = lib.platforms.linux;
  };
})
