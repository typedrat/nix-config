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

  # Upstream DKMS repo (patches + firmware extraction scripts), consumed as a
  # plain non-flake source input. We build the kernel modules ourselves rather
  # than via DKMS so they integrate with NixOS's boot.extraModulePackages. Two
  # details that matter:
  #   1. We install modules to updates/ (not extra/) so depmod ranks them above
  #      the in-tree btusb/btmtk in modules.dep; otherwise the mainline modules
  #      load instead and fail to init the MT6639.
  #   2. The patched btmtk loads BT firmware from mediatek/mt7927/, so the
  #      firmware derivation installs there to match.
  repoSrc = inputs.mediatek-mt7927-dkms;

  # Upstream tracks build metadata in PKGBUILD. Parse the kernel snapshot
  # version, its tarball hash, and the ASUS firmware driver filename/hash
  # straight out of it so a bump of the input picks up new values automatically.
  pkgbuild = builtins.readFile "${repoSrc}/PKGBUILD";

  matchPkgbuild = re: let
    m = builtins.match ".*${re}.*" pkgbuild;
  in
    if m != null
    then builtins.head m
    else null;

  mt76KVer = matchPkgbuild "_mt76_kver='([^']+)'";
  driverFilename = matchPkgbuild "_driver_filename='([^']+)'";
  driverSha256Hex = matchPkgbuild "_driver_sha256='([a-f0-9]+)'";
  # First entry of sha256sums=( ... ) is the kernel tarball hash.
  kernelTarballSha256 = matchPkgbuild "sha256sums=\\('([a-f0-9]+)'";

  # Patch sets, applied in the same order as the upstream Makefile's `sources`
  # target. WiFi: mt7902 compat patch first, then mt7927-wifi-* sorted. BT:
  # mt6639-bt-[0-9]* sorted, then the compat patch. readDir + sort reproduces
  # the Makefile's shell-glob ordering deterministically.
  patchFiles = builtins.attrNames (builtins.readDir repoSrc);
  sortedMatching = re:
    map (n: "${repoSrc}/${n}")
    (builtins.sort builtins.lessThan
      (builtins.filter (n: builtins.match re n != null) patchFiles));

  wifiPatches =
    ["${repoSrc}/mt7902-wifi-6.19.patch"]
    ++ sortedMatching "mt7927-wifi-[0-9].*\\.patch"
    ++ sortedMatching "mt7927-wifi-compat-.*\\.patch";

  btPatches =
    sortedMatching "mt6639-bt-[0-9].*\\.patch"
    ++ sortedMatching "mt6639-bt-compat-.*\\.patch";

  linuxDrivers = pkgs.fetchurl {
    url = "https://cdn.kernel.org/pub/linux/kernel/v${builtins.head (lib.splitString "." mt76KVer)}.x/linux-${mt76KVer}.tar.xz";
    sha256 = kernelTarballSha256;
  };

  asusZip = pkgs.fetchurl {
    url = "https://dlcdnets.asus.com/pub/ASUS/mb/08WIRELESS/${driverFilename}";
    hash = "sha256:${driverSha256Hex}";
    name = "asus-mt7927-driver.zip";
  };

  kernel = config.boot.kernelPackages.kernel;
  isClang = kernel.stdenv.cc.isClang or false;
  kernelBuild = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
  makeFlags =
    if isClang
    then "LLVM=1 CC=clang"
    else "";

  # Firmware extracted from the ASUS Windows driver via the upstream
  # extract_firmware.py. The patched btmtk requests the BT RAM code at
  # mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin (see FIRMWARE_MT7927 in
  # mt6639-bt-01), and the upstream packaging installs it there too. We mirror
  # that layout.
  firmware = kernel.stdenv.mkDerivation {
    pname = "mediatek-mt7927-firmware";
    version = "2.1";
    dontUnpack = true;
    nativeBuildInputs = [pkgs.libarchive pkgs.python3];

    buildPhase = ''
      runHook preBuild
      bsdtar -xf ${asusZip} mtkwlan.dat
      python3 ${repoSrc}/extract_firmware.py mtkwlan.dat firmware/
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      # BT firmware: install to BOTH mt7927/ (driver's request path) and
      # mt6639/ (legacy path) so either driver revision finds it.
      install -Dm644 firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin \
        "$out/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin"
      install -Dm644 firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin \
        "$out/lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin"
      # WiFi firmware.
      install -Dm644 firmware/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin \
        "$out/lib/firmware/mediatek/mt7927/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin"
      install -Dm644 firmware/WIFI_RAM_CODE_MT6639_2_1.bin \
        "$out/lib/firmware/mediatek/mt7927/WIFI_RAM_CODE_MT6639_2_1.bin"
      runHook postInstall
    '';

    meta.license = lib.licenses.unfreeRedistributableFirmware;
  };

  wifi = kernel.stdenv.mkDerivation {
    pname = "mediatek-mt7927-wifi";
    version = "2.1";
    src = linuxDrivers;
    nativeBuildInputs = kernel.moduleBuildDependencies ++ [pkgs.python3 pkgs.perl pkgs.kmod];
    # Unpack only the mt76 driver subtree from the kernel tarball, then apply
    # the WiFi patch series (mt7902 compat + mt7927-wifi-* + compat) the same
    # way the upstream Makefile does.
    unpackPhase = ''
      runHook preUnpack
      tar -xf ${linuxDrivers} \
        "linux-${mt76KVer}/drivers/net/wireless/mediatek/mt76"
      sourceRoot="linux-${mt76KVer}/drivers/net/wireless/mediatek/mt76"
      runHook postUnpack
    '';
    patches = wifiPatches;
    postPatch = ''
      cp ${repoSrc}/mt76.Kbuild Kbuild
      cp ${repoSrc}/mt7921.Kbuild mt7921/Kbuild
      cp ${repoSrc}/mt7925.Kbuild mt7925/Kbuild
      mkdir -p compat/include/linux/soc/airoha
      cp ${repoSrc}/compat-airoha-offload.h \
        compat/include/linux/soc/airoha/airoha_offload.h
    '';
    buildPhase = ''
      runHook preBuild
      make -C ${kernelBuild} M=$(pwd) ${makeFlags} modules
      runHook postBuild
    '';
    # Install to updates/ (depmod's highest-precedence dir) so these override
    # the in-tree mt76/mt7925e modules. extra/ does NOT rank above kernel/, so
    # modules placed there stay unindexed in modules.dep and the mainline ones
    # load instead.
    installPhase = ''
      runHook preInstall
      modDir="$out/lib/modules/${kernel.modDirVersion}/updates/mt76"
      install -dm755 "$modDir/mt7921" "$modDir/mt7925"
      install -m644 mt76.ko mt76-connac-lib.ko mt792x-lib.ko "$modDir/"
      install -m644 mt7921/*.ko "$modDir/mt7921/"
      install -m644 mt7925/*.ko "$modDir/mt7925/"
      runHook postInstall
    '';
  };

  bluetooth = kernel.stdenv.mkDerivation {
    pname = "mediatek-mt7927-bluetooth";
    version = "2.1";
    src = linuxDrivers;
    nativeBuildInputs = kernel.moduleBuildDependencies ++ [pkgs.kmod];
    unpackPhase = ''
      runHook preUnpack
      tar -xf ${linuxDrivers} "linux-${mt76KVer}/drivers/bluetooth"
      sourceRoot="linux-${mt76KVer}/drivers/bluetooth"
      runHook postUnpack
    '';
    patches = btPatches;
    buildPhase = ''
      runHook preBuild
      echo "obj-m += btusb.o btmtk.o" > Makefile
      make -C ${kernelBuild} M=$(pwd) ${makeFlags} modules
      runHook postBuild
    '';
    # updates/ precedence (see wifi note above) so the patched btusb/btmtk win
    # over the in-tree ones that lack MT6639 init + the mt7927 firmware path.
    installPhase = ''
      runHook preInstall
      modDir="$out/lib/modules/${kernel.modDirVersion}/updates/bluetooth"
      install -dm755 "$modDir"
      install -m644 btusb.ko btmtk.ko "$modDir/"
      runHook postInstall
    '';
  };
in {
  options.rat.hardware.mt7927 = {
    enable =
      mkEnableOption "MediaTek MT7927 / MT6639 (Filogic 380) WiFi 7 + Bluetooth";

    enableWifi = mkOption {
      type = types.bool;
      default = true;
      description = "Build and load the patched mt7925e/mt7921e WiFi modules.";
    };

    enableBluetooth = mkOption {
      type = types.bool;
      default = true;
      description = "Build and load the patched btusb/btmtk Bluetooth modules.";
    };

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
    hardware.firmware = [firmware];

    boot.extraModulePackages =
      lib.optional cfg.enableWifi wifi
      ++ lib.optional cfg.enableBluetooth bluetooth;

    boot.kernelModules =
      lib.optionals cfg.enableWifi ["mt7925e" "mt7921e"]
      ++ lib.optionals cfg.enableBluetooth ["btmtk" "btusb"];

    services.udev.extraRules = mkIf cfg.disableAspm ''
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x14c3", ATTR{device}=="0x7927", ATTR{link/l1_aspm}="0"
    '';
  };
}
