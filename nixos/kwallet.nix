{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    kdePackages.kwallet
    kwalletcli
  ];

  security.pam.services.greetd.kwallet = {
    enable = true;
    package = pkgs.kdePackages.kwallet-pam;
    forceRun = true;
  };
}
