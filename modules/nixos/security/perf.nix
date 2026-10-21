{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
  cfg = config.rat.security.perf;
  group = "perf_users";
  wrapper = "${config.security.wrapperDir}/perf";

  # nixpkgs ships bin/perf as a shell wrapper that puts objdump and python on
  # PATH, and security.wrappers refuses non-ELF sources. Rebuild that wrapper
  # as a binary one around the real executable.
  perfBinary =
    pkgs.runCommand "${pkgs.perf.name}-binary-wrapper" {
      nativeBuildInputs = [pkgs.makeBinaryWrapper];
    } ''
      makeBinaryWrapper ${pkgs.perf}/bin/.perf-wrapped $out/bin/perf \
        --inherit-argv0 \
        --prefix PATH : ${lib.makeBinPath [pkgs.binutils-unwrapped pkgs.python3]}
    '';

  perfUsers =
    lib.filterAttrs
    (_: userCfg: userCfg.enable && (userCfg.cli.development.enable or false))
    config.rat.users;
in {
  options.rat.security.perf = {
    enable =
      mkEnableOption "kernel profiling with perf for development users, without loosening perf_event_paranoid or kptr_restrict";

    wrap = mkOption {
      type = types.functionTo types.package;
      readOnly = true;
      description = ''
        Wraps a perf package so its `perf` runs the capability wrapper.
        Returns the package unchanged when kernel profiling is disabled.
        The wrapper always runs the system's perf, not the one passed in.
      '';
      default = pkg:
        if !cfg.enable
        then pkg
        else
          pkgs.symlinkJoin {
            name = "${pkg.name}-capabilities";
            paths = [pkg];
            postBuild = ''
              rm "$out/bin/perf"
              ln -s ${wrapper} "$out/bin/perf"
            '';
            inherit (pkg) meta;
            passthru = pkg.passthru or {};
          };
    };
  };

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
      source = "${perfBinary}/bin/perf";
    };
  };
}
