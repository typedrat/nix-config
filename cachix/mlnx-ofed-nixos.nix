
{
  nix = {
    settings = {
      substituters = [
        "https://mlnx-ofed-nixos.cachix.org"
      ];
      trusted-public-keys = [
        "mlnx-ofed-nixos.cachix.org-1:jL/cqleOzhPw87etuHMeIIdAgFDKX8WnTBYMSBx3toI="
      ];
    };
  };
}
