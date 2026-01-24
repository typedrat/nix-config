_: {
  # Prioritize HDMI 1 (receiver) over HDMI 2 (monitor) on the NVIDIA GPU
  # The receiver takes longer to enumerate at boot, so without this config
  # WirePlumber picks the monitor as default before the receiver appears
  services.pipewire.wireplumber.extraConfig."50-hdmi-priority" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "node.name" = "alsa_output.pci-0000_01_00.1.hdmi-stereo";
          }
        ];
        actions = {
          update-props = {
            "priority.session" = 10000;
          };
        };
      }
      {
        matches = [
          {
            "node.name" = "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1";
          }
        ];
        actions = {
          update-props = {
            "priority.session" = 1000;
          };
        };
      }
    ];
  };
}
