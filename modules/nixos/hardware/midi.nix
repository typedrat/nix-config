{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) literalExpression types;

  cfg = config.rat.audio.midi;

  # fluidsynth's CMake turns enable-pipewire on by default, but nixpkgs never
  # passes libpipewire, so the stock build silently ships without the driver
  # and `-a help` lists only alsa/file/jack/oss/pulseaudio. Reaching PipeWire
  # through its PulseAudio shim instead would put an extra resampling hop in
  # the path of a live synth.
  fluidsynth = pkgs.fluidsynth.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [pkgs.pipewire];
  });
in {
  options.rat.audio.midi = {
    enable = mkEnableOption "FluidSynth as the system MIDI synthesizer";

    package = mkOption {
      type = types.package;
      default = fluidsynth;
      defaultText = literalExpression "pkgs.fluidsynth with the PipeWire audio driver enabled";
      description = "FluidSynth package to run as the MIDI synthesizer.";
    };

    soundFontPackages = mkOption {
      type = types.listOf types.package;
      default = [pkgs.soundfont-generaluser-gs];
      defaultText = literalExpression "[pkgs.soundfont-generaluser-gs]";
      description = ''
        SoundFont packages to install system-wide. Their `share/soundfonts`
        directories are what applications searching `XDG_DATA_DIRS` will find.
      '';
    };

    soundFont = mkOption {
      type = types.path;
      default = "${pkgs.soundfont-generaluser-gs}/share/soundfonts/GeneralUser-GS.sf2";
      defaultText = literalExpression ''"''${pkgs.soundfont-generaluser-gs}/share/soundfonts/GeneralUser-GS.sf2"'';
      description = ''
        The system-wide default SoundFont. Used by FluidSynth when no bank is
        named on the command line, and exposed as
        {file}`/usr/share/soundfonts/default.sf2`.
      '';
    };

    blacklistSeqDummy =
      mkEnableOption "blacklisting snd_seq_dummy so FluidSynth is the first ALSA sequencer client"
      // {default = true;};

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = "set synth.gain 0.4";
      description = ''
        FluidSettings commands appended to {file}`/etc/fluidsynth.conf`. Later
        settings win, so these override the defaults set by this module.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.rat.audio.enable;
        message = "rat.audio.midi requires rat.audio.enable: FluidSynth outputs through PipeWire.";
      }
    ];

    # alsa-utils supplies aconnect and aplaymidi, which are how you inspect and
    # drive the sequencer port the daemon registers.
    environment.systemPackages =
      [cfg.package pkgs.alsa-utils] ++ cfg.soundFontPackages;

    # fluidsynth hardcodes this path on Linux (fluid_get_sysconf), and reads it
    # before user config and before -f, so it is the one true system-wide hook.
    environment.etc."fluidsynth.conf".text = ''
      set synth.default-soundfont ${cfg.soundFont}
      set audio.driver pipewire
      set midi.driver alsa_seq
      set synth.sample-rate 48000

      # Matches the 512-frame min-quantum PipeWire is pinned to here; smaller
      # periods underrun on this box and come out as crackle.
      set audio.period-size 512
      ${cfg.extraConfig}
    '';

    # Nothing outside the Nix store looks in /run/current-system/sw for banks.
    # Wine, ScummVM, DOSBox and friends expect the FHS location, so a default
    # SoundFont that is only reachable by store path is not actually a default.
    systemd.tmpfiles.rules = [
      "d /usr/share/soundfonts 0755 root root -"
      "L+ /usr/share/soundfonts/default.sf2 - - - - ${cfg.soundFont}"
    ];

    # snd_seq_dummy's 'Midi Through' ports register as kernel clients and so sort
    # ahead of any synth. Applications that grab the first sequencer client
    # rather than offering a choice — Wine and Proton among them — send their
    # MIDI there and play nothing.
    boot.blacklistedKernelModules = mkIf cfg.blacklistSeqDummy ["snd_seq_dummy"];

    systemd.user.services.fluidsynth = {
      description = "FluidSynth MIDI synthesizer";
      documentation = ["man:fluidsynth(1)"];
      bindsTo = ["pipewire.service"];
      after = ["pipewire.service"];
      wantedBy = ["default.target"];

      serviceConfig = {
        # No arguments: every setting comes from /etc/fluidsynth.conf.
        #
        # -s is load-bearing, not decoration. Given -i alone fluidsynth builds
        # the audio driver, finds nothing left to block on and returns 0, so the
        # unit would exit the moment it finished starting. Only the user shell
        # or the server's join keeps the process alive.
        ExecStart = "${lib.getExe cfg.package} -si";
        Restart = "on-failure";
        RestartSec = 1;

        # The price of -s is an unauthenticated command shell on TCP 9800 bound
        # to INADDR_ANY, able to load arbitrary files. A private netns leaves it
        # bound to nothing reachable; the sequencer port is a character device
        # and PipeWire a unix socket, so neither notices.
        PrivateNetwork = true;
      };
    };
  };
}
