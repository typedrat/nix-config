{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.rat.ssh;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.ssh = {
    enable = mkEnableOption "ssh" // {default = true;};
  };

  config = mkMerge [
    (mkIf cfg.enable {
      # Ensure SSH and mosh are globally available
      environment.systemPackages = with pkgs; [
        openssh
      ];

      environment.enableAllTerminfo = true;

      services.openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
        };

        extraConfig = ''
          AllowAgentForwarding = yes
        '';
      };

      programs.mosh = {
        enable = true;
        openFirewall = true;
      };

      programs.ssh = {
        startAgent = true;

        # Add GitHub's public SSH keys to knownHosts
        knownHosts = {
          "github.com" = {
            hostNames = ["github.com"];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
          };
          "github.com-rsa" = {
            hostNames = ["github.com"];
            publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA1+NjMdJmN8pJHGYIc/QUj9dJR1S6hW5cNxNVY9+7p9cW0VkE4sDL2+7DW3x7xAW5Ygzf1J9F2xB+5zPz+1qgj2+PZcU3U0tJjCO2d2CXvDL1OAGfHJ5";
          };
          "github.com-ecdsa" = {
            hostNames = ["github.com"];
            publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
          };
        };
      };
    })
    (mkIf impermanenceCfg.enable {
      services.openssh = {
        hostKeys = [
          {
            type = "ed25519";
            path = "${impermanenceCfg.persistDir}/etc/ssh/ssh_host_ed25519_key";
          }
          {
            type = "rsa";
            bits = 4096;
            path = "${impermanenceCfg.persistDir}/etc/ssh/ssh_host_rsa_key";
          }
        ];
      };
    })
  ];
}
