{pkgs, ...}: let
  # DP-1's EDID (Dell S2725QS) with its CEA-861 audio capability stripped: the
  # Basic-Audio flag is cleared and the single Short Audio Descriptor removed.
  # Every video, timing, VRR and HDR field is byte-for-byte the original, so the
  # only behavioural change is that the monitor advertises no audio.
  dellNoAudioEdid = pkgs.runCommand "dell-s2725qs-noaudio-edid" {} ''
    install -Dm444 ${./dell-s2725qs-noaudio.bin} \
      "$out/lib/firmware/edid/dell-s2725qs-noaudio.bin"
  '';
in {
  # There is never any use for audio out of the Dell monitor; only the Denon
  # receiver on HDMI-A-1 should carry audio. Steering this in userspace is
  # unreliable: PipeWire's ACP exposes only one NVIDIA HDMI sink at a time and
  # auto-selects the always-present monitor, while the receiver enumerates its
  # ELD slowly and loses the race. Nothing downstream offers a stable handle for
  # "the monitor" — sinks are positional slots (hdmi-stereo-extraN) whose display
  # binding isn't fixed across boots — and NVIDIA's HDMI codec silently discards
  # static HDA pin-config overrides. The one stable identifier is the physical
  # DP-1 connector, so the fix lives at the EDID: a monitor that advertises no
  # audio can never present an audio sink, and its video is untouched.
  #
  # NVIDIA does early KMS from the initrd (nvidia_drm is in
  # boot.initrd.kernelModules), so the EDID has to be in the initrd to win the
  # first connector probe; on the proprietary driver drm.edid_firmware also only
  # takes effect alongside a matching `video=<output>:e`.
  hardware.display = {
    edid.packages = [dellNoAudioEdid];
    outputs."DP-1" = {
      edid = "dell-s2725qs-noaudio.bin";
      mode = "e";
    };
  };

  boot.initrd.extraFirmwarePaths = ["edid/dell-s2725qs-noaudio.bin"];
}
