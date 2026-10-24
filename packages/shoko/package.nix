{
  lib,
  buildDotnetModule,
  fetchFromGitHub,
  dotnet-sdk_10,
  dotnet-aspnetcore_10,
  mediainfo,
  rhash,
  avdump3,
}:
buildDotnetModule (finalAttrs: {
  pname = "shoko";
  # The daily dev builds, not the stable releases: the database has been
  # migrated to the 6.0 dev schema, and Shoko can't migrate back down.
  version = "6.0.0-dev.550";

  src = fetchFromGitHub {
    owner = "ShokoAnime";
    repo = "ShokoServer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-w8xjsfgwqkEGfbJty7FKbSJJioFqtxcrzs4em8wliag=";
  };

  # Shoko downloads AVDump into its working directory and runs it through
  # `dotnet`; point it at the packaged one instead. Edited by string rather
  # than a patch so a daily bump fails on the exact line that moved.
  postPatch = ''
    substituteInPlace Shoko.Server/Utilities/AVDumpHelper.cs \
      --replace-fail \
        'Path.Combine(WorkingDirectory, PlatformUtility.IsWindows ? "AVDump3CL.exe" : "AVDump3CL.dll")' \
        '"${lib.getExe avdump3}"' \
      --replace-fail 'if (!PrepareAVDump())' 'if (AVDumpExecutable == null)' \
      --replace-fail 'startInfo.FileName = "dotnet";' 'startInfo.FileName = AVDumpExecutable;' \
      --replace-fail 'startInfo.ArgumentList.Add(AVDumpExecutable);' ""

    # The bundled plugins are built by a nested MSBuild call that inherits the
    # install hook's NoBuild=true, and building with it set is an error.
    substituteInPlace BundledPlugins.targets \
      --replace-fail 'RemoveProperties="RuntimeIdentifier;' 'RemoveProperties="NoBuild;RuntimeIdentifier;'
  '';

  dotnet-sdk = dotnet-sdk_10;
  dotnet-runtime = dotnet-aspnetcore_10;

  nugetDeps = ./deps.json;
  projectFile = "Shoko.CLI/Shoko.CLI.csproj";
  dotnetBuildFlags = "/p:InformationalVersion=\"channel=dev,tag=v${finalAttrs.version}\"";

  executables = ["Shoko.CLI"];
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${mediainfo}/bin"
  ];
  runtimeDeps = [rhash];

  passthru.updateScript = ./update.sh;

  meta = {
    homepage = "https://github.com/ShokoAnime/ShokoServer";
    changelog = "https://github.com/ShokoAnime/ShokoServer/releases/tag/v${finalAttrs.version}";
    description = "Backend for the Shoko anime management system";
    license = lib.licenses.mit;
    mainProgram = "Shoko.CLI";
    inherit (dotnet-sdk_10.meta) platforms;
  };
})
