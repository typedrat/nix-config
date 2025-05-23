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
  version = "5.1.0-dev.80";

  src = fetchFromGitHub {
    owner = "ShokoAnime";
    repo = "ShokoServer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-zC6NIVcUgDG8iibUTM1jbHPpKYEhc87NXP+9O5awQFc=";
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
