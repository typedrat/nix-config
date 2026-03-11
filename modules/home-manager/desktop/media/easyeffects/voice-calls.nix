{
  services.easyeffects.extraPresets."Voice Calls" = {
    input = {
      blocklist = [];

      plugins_order = [
        "autogain#0"
        "compressor#0"
        "rnnoise#0"
        "gate#0"
      ];

      "autogain#0" = {
        bypass = false;
        input-gain = 0.0;
        maximum-history = 15;
        output-gain = 0.0;
        reference = "Geometric Mean (MSI)";
        silence-threshold = -70.0;
        target = -23.0;
      };

      "compressor#0" = {
        attack = 20.0;
        boost-amount = 6.0;
        boost-threshold = -72.0;
        bypass = false;
        dry = -100.0;
        hpf-frequency = 10.0;
        hpf-mode = "off";
        input-gain = 0.0;
        knee = -6.0;
        lpf-frequency = 20000.0;
        lpf-mode = "off";
        makeup = 0.0;
        mode = "Upward";
        output-gain = 0.0;
        ratio = 4.0;
        release = 100.0;
        release-threshold = -100.0;
        sidechain = {
          lookahead = 0.0;
          mode = "RMS";
          preamp = 0.0;
          reactivity = 10.0;
          source = "Middle";
          stereo-split-source = "Left/Right";
          type = "Feed-forward";
        };
        stereo-split = false;
        threshold = -12.0;
        wet = 0.0;
      };

      "rnnoise#0" = {
        bypass = false;
        enable-vad = true;
        input-gain = 0.0;
        model-name = "";
        output-gain = 0.0;
        release = 50.0;
        vad-thres = 50.0;
        wet = 0.0;
      };

      "gate#0" = {
        attack = 100.0;
        bypass = false;
        curve-threshold = -24.0;
        curve-zone = -6.0;
        dry = -100.0;
        hpf-frequency = 10.0;
        hpf-mode = "off";
        hysteresis = false;
        hysteresis-threshold = -12.0;
        hysteresis-zone = -6.0;
        input-gain = 0.0;
        lpf-frequency = 20000.0;
        lpf-mode = "off";
        makeup = 0.0;
        output-gain = 0.0;
        reduction = -24.0;
        release = 100.0;
        sidechain = {
          input = "Internal";
          lookahead = 0.0;
          mode = "RMS";
          preamp = 0.0;
          reactivity = 10.0;
          source = "Middle";
          stereo-split-source = "Left/Right";
        };
        stereo-split = false;
        wet = 0.0;
      };
    };
  };
}
