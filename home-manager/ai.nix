{
  pkgs,
  lib,
  config,
  ...
}: {
  systemd.user.services.sillytavern = {
    Unit = {
      Description = "SillyTavern AI Frontend Service";
      After = ["network.target"];
    };
    Service = {
      ExecStart = "${pkgs.bash}/bin/bash ./start.sh";
      Environment = [
        "PATH=$PATH:${lib.makeBinPath [pkgs.nodejs_22 pkgs.corepack_22]}"
      ];
      WorkingDirectory = "${config.home.homeDirectory}/AI/SillyTavern";
      Restart = "on-failure";
    };
    Install = {WantedBy = ["default.target"];};
  };
}
