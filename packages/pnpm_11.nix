{
  callPackage,
  inputs,
}:
(callPackage "${inputs.nixpkgs}/pkgs/development/tools/pnpm/generic.nix" {
  version = "11.0.0-alpha.14";
  hash = "sha256-hRHeZI/VonE+Pa1tYI+avnvh7r1bOoqZ13hRopHbuUY=";
})
.overrideAttrs (prev: {
  postInstall =
    (prev.postInstall or "")
    + ''
      chmod +x $out/bin/*
    '';
})
