{
  buildDotnetModule,
  fetchFromGitHub,
  dotnet-sdk_8,
  dotnet-aspnetcore_8,
  nixosTests,
  lib,
  mediainfo,
  rhash,
}:
buildDotnetModule (finalAttrs: {
  pname = "shoko-dev";
  version = "5.1.0-dev.126";

  src = fetchFromGitHub {
    owner = "ShokoAnime";
    repo = "ShokoServer";
    rev = "v${finalAttrs.version}";
    hash = "sha256-kWYE6D+CYPKRWosrThS+YiwdXj8m7jdk4VplAyBfuyY=";
    fetchSubmodules = true;
  };

  dotnet-sdk = dotnet-sdk_8;
  dotnet-runtime = dotnet-aspnetcore_8;

  nugetDeps = ./deps.json;
  projectFile = "Shoko.CLI/Shoko.CLI.csproj";
  dotnetBuildFlags = "/p:Version=\"${builtins.replaceStrings ["-dev"] [""] finalAttrs.version}\" /p:InformationalVersion=\"channel=dev\",commit=,tag=v${finalAttrs.version},date=";

  executables = ["Shoko.CLI"];
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${mediainfo}/bin"
  ];
  runtimeDeps = [rhash];

  passthru.tests.shoko = nixosTests.shoko;

  meta = {
    homepage = "https://github.com/ShokoAnime/ShokoServer";
    changelog = "https://github.com/ShokoAnime/ShokoServer/releases/tag/v${finalAttrs.version}";
    description = "Backend for the Shoko anime management system (daily build)";
    license = lib.licenses.mit;
    mainProgram = "Shoko.CLI";
    inherit (dotnet-sdk_8.meta) platforms;
  };
})
