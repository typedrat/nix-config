{pkgs, ...}: {
  # Add MSI MPG X870I EDGE TI WIFI (0db0:4c84) to the ALC4080 UCM config
  nixpkgs.overlays = [
    (final: prev: {
      alsa-ucm-conf = prev.alsa-ucm-conf.overrideAttrs (oldAttrs: {
        postInstall =
          (oldAttrs.postInstall or "")
          + ''
            substituteInPlace $out/share/alsa/ucm2/USB-Audio/USB-Audio.conf \
              --replace-fail \
                '# 0db0:cd0e MSI X870 Tomahawk' \
                '# 0db0:4c84 MSI MPG X870I EDGE TI WIFI
                # 0db0:cd0e MSI X870 Tomahawk' \
              --replace-fail \
                '4(19c|22d|240|88c)' \
                '4(19c|22d|240|88c|c84)'
          '';
      });
    })
  ];
}
