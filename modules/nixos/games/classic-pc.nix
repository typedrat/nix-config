{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  group = "86box";

  classicPCUsers =
    lib.filterAttrs
    (_: userCfg:
      userCfg.enable
      && (userCfg.gui.enable or false)
      && (userCfg.gui.gaming.classicPC.enable or false))
    config.rat.users;

  # The sound samples for floppy and hard disk audio ship in a separate asset
  # pack, which 86Box looks for in share/86Box/assets alongside the ROMs.
  # Fetched by tag, so the hash is only right for one release: a stale hash
  # would silently reuse the old pack rather than fail.
  _86box = let
    base = pkgs._86box.override {
      unfreeEnableDiscord = true;
      unfreeEnableRoms = true;
    };
  in
    assert lib.assertMsg (base.version == "6.0")
    "86box is now ${base.version}; update the asset pack tag hash in classic-pc.nix";
      base.overrideAttrs (old: {
        postInstall =
          old.postInstall
          + ''
            ln -s ${pkgs.fetchFromGitHub {
              owner = "86Box";
              repo = "assets";
              tag = "v${old.version}";
              hash = "sha256-7Fl0o48HT6XAYVQEsGUG6TbJlHFHLIKn7OcOrhkeGI8=";
            }} $out/share/86Box/assets
          '';
      });
in {
  options.rat.gaming.classicPC.package = mkOption {
    type = types.package;
    readOnly = true;
    default = _86box;
    description = "The 86Box build that rat.users.<name>.gui.gaming.classicPC installs.";
  };

  config = mkIf (classicPCUsers != {}) {
    users.groups.${group} = {};
    users.users = lib.mapAttrs (_: _: {extraGroups = [group];}) classicPCUsers;

    # 86Box's TAP backend always creates a fresh TAP device, brings it up and
    # adds it to the bridge named in the VM's settings, all of which need
    # CAP_NET_ADMIN; there's no way to hand it a pre-made persistent TAP.
    # CAP_NET_RAW is for the PCap backend. The wrapper raises both into the
    # ambient set, so they survive the package's own LD_LIBRARY_PATH wrapper
    # exec'ing the real binary.
    security.wrappers."86Box" = {
      owner = "root";
      inherit group;
      permissions = "u+rx,g+x";
      capabilities = "cap_net_admin,cap_net_raw+ep";
      source = "${_86box}/bin/86Box";
    };
  };
}
