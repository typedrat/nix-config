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

    # The bundled plugins are built by a nested MSBuild call with different
    # global properties, so MSBuild builds their project references (the
    # whole server among them) a second time. Those copies come out without
    # the package version, and in the default bin/ they overwrite the ones
    # the server was compiled against; give them a bin of their own. The
    # call also inherits the install hook's NoBuild=true, which is an error
    # when building.
    substituteInPlace BundledPlugins.targets \
      --replace-fail 'RemoveProperties="RuntimeIdentifier;' 'RemoveProperties="NoBuild;RuntimeIdentifier;' \
      --replace-fail 'Platform=$(Platform)"' 'Platform=$(Platform);BaseOutputPath=bin-bundled/"'
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

  # Shoko extracts each plugin's embedded thumbnail and icon into the plugin's
  # directory on startup unless a file of that name is already there, and the
  # write fails in the store. Ship the bundled plugin's images instead.
  postInstall = ''
    cp Shoko.Plugin.LegacyPlex/Assets/thumbnail.svg Shoko.Plugin.LegacyPlex/Assets/icon.svg \
      "$out/lib/shoko/plugins/Shoko.Plugin.LegacyPlex/"
  '';

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
