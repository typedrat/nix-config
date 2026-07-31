{lib, ...}: let
  inherit (lib) options types;
in {
  imports = [
    ./networkmanager.nix
    ./scoped-ports.nix
  ];

  options.rat.networking.lanRanges = options.mkOption {
    type = types.listOf types.str;
    description = ''
      Source ranges treated as "the local network" by `rat.networking.scopedPorts`.

      The IPv6 global prefix is a delegation from the ISP rather than anything
      this configuration controls. Hosts reach each other over it by preference
      (RFC 6724 ranks a global prefix above a unique-local one), so it has to be
      listed, and it has to be corrected here if the delegation ever rotates —
      the symptom is every cross-host scrape failing at once.
    '';
    default = [
      "10.0.0.0/24"
      "fdb1:d67d:2e17::/48"
      "2601:204:f381:4784::/64"
    ];
  };
}
