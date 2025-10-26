{pkgs, ...}: {
  rat.users.awilliams = {
    uid = 1000;
    isNormalUser = true;
    home = "/home/awilliams";
    extraGroups = [
      "dialout"
      "games"
      "wheel"
    ];
    shell = pkgs.zsh;
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFCm+qnsWUuTDU6IgvxPAkfe6dnwwomGQXlM9c2yUqlJ awilliams@hyperion"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBjz3PWnehAKNKXGpkDu+Huiyizd/24efmLmJCoct+KP awilliams@hyperion-windows"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLI5a9axsIGCRFLzb9lviLINzebCWV68O94WlXRnMkEKO8uqLAJHGy2aw8i/rB4TcLfqP5lBvOZn0nCNRTvZIRg= awilliams@ipad"
    ];

    cli.enable = true;
    theming.enable = true;
  };
}
