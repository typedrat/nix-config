{pkgs, ...}: {
  rat.users.sioned = {
    uid = 1001;
    isNormalUser = true;
    home = "/home/sioned";
    shell = pkgs.zsh;
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGYrpKrD5ztO7nlJM6IxI/2lxKnLgmziGVBU3JX2X+iX sione@sioned-ROG"
    ];

    cli.enable = true;
  };
}
