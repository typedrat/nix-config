{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  cfg = config.rat.security.perf;
  group = "perf_users";

  perfUsers =
    lib.filterAttrs
    (_: userCfg: userCfg.enable && (userCfg.cli.development.enable or false))
    config.rat.users;
in {
  options.rat.security.perf.enable =
    mkEnableOption "kernel profiling with perf for development users, without loosening perf_event_paranoid or kptr_restrict";

  config = mkIf cfg.enable {
    users.groups.${group} = {};
    users.users = lib.mapAttrs (_: _: {extraGroups = [group];}) perfUsers;

    # The wrapper raises its capabilities into the ambient set, so the workload
    # that `perf record -- cmd` starts inherits them too. CAP_PERFMON and
    # CAP_SYSLOG only widen what that process can observe; CAP_SYS_PTRACE is
    # left out because a workload holding it could attach to root's processes.
    # Profiling other users' processes still needs `sudo perf`.
    security.wrappers.perf = {
      owner = "root";
      inherit group;
      permissions = "u+rx,g+x";
      capabilities = "cap_perfmon,cap_syslog+ep";
      source = lib.getExe pkgs.perf;
    };
  };
}
