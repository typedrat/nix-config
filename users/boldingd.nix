{pkgs, ...}: {
  rat.users.boldingd = {
    uid = 1002;
    isNormalUser = true;
    home = "/home/boldingd";
    shell = pkgs.zsh;
    sshKeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDwxW2eSdSx0wZFRtYLqRhaiW2g8vrIWMtwL1O4ftti1s9WEGqghjG8d9kUKk3lZ7vTm3bg1Id0oKPWj3uwVg5SKqr1vcxXWXQqRP2t+prZxzs3sWqqOiddHsPplZZ7DN7e/tWw8X9EgW0SZPigqb9TUOFZvDm6OABxFVVhbC5OZudQQcfbnVEYZ8LK2414Jzs0z77dDkba4c8UIH4/2M+a9GpOo9nTy1+U4PqnhiLKmgMNvRkcRPqauUozNhJheNyz6xZERToP+GW/cCIjPw2XAq3su/NY0ha/XYaib8k1e9fpmOE7paG//UBoS09YCTaKXFnGyDppZ1Hbt6enVgX6qNEuxT5sLZdu8U8AvQJDg+zxXQBrldsWMx+6BUkHBZI/LOpiDhfWx1VhAQjw0mpVboZVj7hMijd32J1bgoiJljO7IT2EB5i/YysEduN7f4GnKVAkYANLh095L6jgcsDE8KU/Vdg16Dwe3c0I5D9SGAFC0qStY3imjqkB13i5cOM= boldingd@the-stryx"
    ];

    cli.enable = true;
  };
}
