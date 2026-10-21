{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types;

  cfg = config.rat.hardware.mt7927;

  # Kernels from 7.2 carry the MT7927 WiFi driver and from 7.1 the MT6639
  # Bluetooth init, so the only out-of-tree piece left is the Bluetooth RAM
  # code, which linux-firmware does not ship. It is extracted from ASUS's
  # Windows driver using the extraction script from the upstream DKMS repo
  # (a plain non-flake input), and the driver filename/hash are read from its
  # PKGBUILD so bumping the input picks up new values.
  repoSrc = inputs.mediatek-mt7927-dkms;
  pkgbuild = builtins.readFile "${repoSrc}/PKGBUILD";

  matchPkgbuild = re: let
    m = builtins.match ".*${re}.*" pkgbuild;
  in
    if m != null
    then builtins.head m
    else null;

  driverFilename = matchPkgbuild "_driver_filename='([^']+)'";
  driverSha256Hex = matchPkgbuild "_driver_sha256='([a-f0-9]+)'";

  asusZip = pkgs.fetchurl {
    url = "https://dlcdnets.asus.com/pub/ASUS/mb/08WIRELESS/${driverFilename}";
    hash = "sha256:${driverSha256Hex}";
    name = "asus-mt7927-driver.zip";
  };

  # The in-tree btmtk requests the BT RAM code at
  # mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin.
  firmware = pkgs.stdenvNoCC.mkDerivation {
    pname = "mediatek-mt7927-bt-firmware";
    version = "2.1";
    dontUnpack = true;
    nativeBuildInputs = [pkgs.libarchive pkgs.python3];

    buildPhase = ''
      runHook preBuild
      bsdtar -xf ${asusZip} mtkwlan.dat
      python3 ${repoSrc}/extract_firmware.py mtkwlan.dat firmware/ --bluetooth-only
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm644 firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin \
        "$out/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin"
      runHook postInstall
    '';

    meta.license = lib.licenses.unfreeRedistributableFirmware;
  };
in {
  options.rat.hardware.mt7927 = {
    enable =
      mkEnableOption "MediaTek MT7927 / MT6639 (Filogic 380) WiFi 7 + Bluetooth";

    disableAspm = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Disable PCIe ASPM for the MT7927, which fixes "stuck upload" and
        packet-loss issues on this card.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "7.2";
        message = "rat.hardware.mt7927 relies on the in-tree MT7927 drivers, which need kernel 7.2 or newer.";
      }
    ];

    hardware.firmware = [firmware];

    services.udev.extraRules = mkIf cfg.disableAspm ''
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x14c3", ATTR{device}=="0x7927", ATTR{link/l1_aspm}="0"
    '';
  };
}
