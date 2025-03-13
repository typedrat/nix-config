{
  programs.java = {
    enable = true;
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
