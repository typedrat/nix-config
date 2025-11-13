{pkgs, ...}: {
  rat.users.sioned = {
    uid = 1001;
    isNormalUser = true;
    home = "/home/sioned";
    shell = pkgs.zsh;
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGYrpKrD5ztO7nlJM6IxI/2lxKnLgmziGVBU3JX2X+iX sione@sioned-ROG"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCmvcCAaR5e0me7YpP9SylJy4FKc1FRpu4ON9akgl4tDvj8sVOK3T5N0A8kIQPJMi1y+KBY0BlxWKqvL5kCk5adXrz5u2ID/4mqpbWXlxBF7NQgDWyAbzGX9ZslRyRYLwmlcaPWci9f5pS3uZBHRk6M76ctekuBywcEErYfWcwZ1u0a24q2rf8bQlKtkjq2zPOjgGDcQmmCcsxvG/LF87LaH18aScVhLZtDXo8bflfveXLJ18qZvHvFDbdXJsjDVH0JkrhccHHdtuqxen06caspx+UyvPsfWWO6iJY4iknCbtGNRwkZv0UKXXs8hivtub0eHWBhLuBIjJEr3BZwjyxvuheIWzWEoZ2PdoFK0zNstqfdueKAYd0XmuEtgI1fhGpPv2wFYHqPT4hYrRDl1FT7WMv+ram5tnQhHnc1+Ep2ntdZqq1hCtaS/7WY4ZopZQwSM1f5/RIYg+Z47uSsHmpO63Pr7SiG17qt5lroMFkKFhA8Ujk4Hsa0TyQAjENiLnEatknoaH734iVfCUgYtL4V1yg9ZUEh2riJmAPDQ0V9eVlFz5lyv0krrDSaJnQi/rziNVHM5eCkF9xc4uzDBYenKLeeDnUFjXFcHbbebMEVYgyJ9v7XqO6Wbo7xh3p/AqZFfhSlEFtAOsd86Kwn6oXiPFiNc0Gqr/V2/nHBB98+bw== ShellFish@iPhone-12112025"
    ];

    cli.enable = true;
  };
}
