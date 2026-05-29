{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # Granted's `granted completion --shell zsh` is interactive — it writes
  # `_granted` and `_assume` to a config dir and appends `fpath=(...)` lines
  # to `~/.zshenv`, which fails under home-manager (read-only dotfiles).
  # Reproduce the same completion files declaratively from the upstream
  # templates and ship them via a zsh plugin so they land on fpath.
  # Templates: https://github.com/common-fate/granted/tree/main/pkg/granted/templates
  grantedCompletions = pkgs.runCommandLocal "granted-zsh-completions" {} ''
    mkdir -p $out
    cat > $out/_assume <<'EOF'
    #compdef assume
    local -a opts
    local cur
    cur=''${words[-1]}
    if [[ "$cur" == "-"* ]]; then
      opts=("''${(@f)$(FORCE_NO_ALIAS=true assumego ''${words[@]:1:#words[@]-1} ''${cur} --generate-bash-completion)}")
    else
      opts=("''${(@f)$(FORCE_NO_ALIAS=true assumego ''${words[@]:1:#words[@]-1} --generate-bash-completion)}")
    fi
    if [[ "''${opts[1]}" != "" ]]; then
      _describe 'values' opts
    else
      _files
    fi
    EOF
    cat > $out/_granted <<'EOF'
    #compdef granted
    local -a opts
    local cur
    cur=''${words[-1]}
    if [[ "$cur" == "-"* ]]; then
      opts=("''${(@f)$(_CLI_ZSH_AUTOCOMPLETE_HACK=1 ''${words[@]:0:#words[@]-1} ''${cur} --generate-bash-completion)}")
    else
      opts=("''${(@f)$(_CLI_ZSH_AUTOCOMPLETE_HACK=1 ''${words[@]:0:#words[@]-1} --generate-bash-completion)}")
    fi
    if [[ "''${opts[1]}" != "" ]]; then
      _describe 'values' opts
    else
      _files
    fi
    EOF
  '';
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        {
          directory = ".aws";
          mode = "0700";
        }
        {
          directory = ".kube";
          mode = "0700";
        }
        ".config/granted"
        ".cloudflared"
        ".config/gcloud"
        ".config/terraform"
        ".cache/terraform/plugins"
      ];
    };
    home.packages = with pkgs; [
      # Cloud platforms
      google-cloud-sdk
      aws-vault
      ssm-session-manager-plugin

      # Kubernetes tools
      kubectl
      kubectl-cnpg
      kubectl-explore
      kubectl-images
      kubectl-klock
      kubectl-ktop
      kubectl-neat
      kubectl-tree
      kubectl-view-allocations
      kubectl-view-secret
      kubernetes-helm
      cilium-cli

      # Infrastructure as Code
      opentofu
    ];

    programs.awscli.enable = true;

    programs.kubecolor = {
      enable = true;
      enableAlias = true;
    };

    programs.granted.enable = true;

    programs.zsh.plugins = [
      {
        name = "granted-completions";
        src = grantedCompletions;
      }
    ];
  };
}
