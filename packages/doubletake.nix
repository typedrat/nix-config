{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeBinaryWrapper,
  installShellFiles,
  gst_all_1,
  pipewire,
  pulseaudio,
  xrandr,
  nix-update-script,
}: let
  # Capture and encoding run in gst-launch-1.0 child processes, so everything
  # GStreamer needs is resolved at runtime through the wrapper's environment.
  gstPlugins = with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
    pipewire
  ];
in
  buildGoModule (finalAttrs: {
    pname = "doubletake";
    version = "0.5.0";

    src = fetchFromGitHub {
      owner = "omarroth";
      repo = "doubletake";
      tag = "v${finalAttrs.version}";
      hash = "sha256-rsxZ/UL4Pv32+timlohcue0GZcZOrAIrUkR1FX6CyTI=";
    };

    vendorHash = "sha256-cgvY9MVGe8I3g3Ni2sGucTY6YCyPJ2YnoxxUaYfl1E4=";

    subPackages = [
      "cmd/doubletake"
      "cmd/doubletake-ctl"
      "cmd/doubletake-test-receiver"
    ];

    ldflags = [
      "-s"
      "-w"
    ];

    nativeBuildInputs = [
      makeBinaryWrapper
      installShellFiles
    ];

    postInstall = ''
      installManPage man/man1/*.1
      mkdir -p $out/share/plasma/plasmoids
      cp -r plasmoid $out/share/plasma/plasmoids/org.doubletake.plasmoid
    '';

    postFixup = ''
      wrapProgram $out/bin/doubletake \
        --prefix PATH : ${lib.makeBinPath [gst_all_1.gstreamer pulseaudio xrandr]} \
        --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPlugins}
    '';

    passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

    meta = {
      description = "AirPlay screen mirroring sender for Linux";
      homepage = "https://github.com/omarroth/doubletake";
      changelog = "https://github.com/omarroth/doubletake/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.lgpl3Plus;
      mainProgram = "doubletake";
      inherit (pipewire.meta) platforms;
    };
  })
