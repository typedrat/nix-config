{
  user.users.nixremote = {
    description = "nixos remote builder";
    isSystemUser = true;
    createHome = false;

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMjmWjAjprpFLnyza16dISaVHY5YxbqbsJIe5UTTATbY awilliams@hyperion"
    ];

    uid = 500;
    group = "nixremote";
    useDefaultShell = true;
  };

  users.groups.nixremote = {
    gid = 500;
  };

  nix.settings.trusted-users = ["nixremote"];
}
