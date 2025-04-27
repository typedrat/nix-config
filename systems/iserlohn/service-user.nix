{
  users = {
    users.media = {
      uid = 911;
      isSystemUser = true;
      home = "/var/lib/media";
      createHome = true;
      group = "media";
    };

    users.awilliams = {
      extraGroups = ["media"];
    };

    groups.media = {
      gid = 911;
    };
  };

  environment.persistence."/persist" = {
    enable = true;
    directories = [
      "/var/lib/media"
    ];
  };
}
