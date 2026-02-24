_: {
  # Pin the NVIDIA GPU HDMI audio card to the receiver (HDMI 1) profile.
  # Without this, WirePlumber may auto-select the XB321HK monitor (HDMI 2)
  # which has unusable speakers.
  services.pipewire.wireplumber.extraConfig."50-hdmi-profile" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "device.name" = "alsa_card.pci-0000_01_00.1";
          }
        ];
        actions = {
          update-props = {
            "device.profile" = "output:hdmi-stereo";
          };
        };
      }
    ];
  };
}
