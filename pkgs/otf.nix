{
  lib,
  fetchFromGitHub,
  buildGoModule,
  git,
}:
buildGoModule rec {
  pname = "otf";
  version = "0.3.19";

  src = fetchFromGitHub {
    owner = "leg100";
    repo = "otf";
    rev = "v${version}";
    hash = "sha256-dsTciE4iY5Qj/R2Wz5bPKemmW9ijYieOLn563noCIws=";
    leaveDotGit = true;
    postFetch = ''
      cd "$out"
      git rev-parse HEAD > $out/COMMIT_HASH
      date -u -d "@$(git log -1 --pretty=%ct)" "+%s" > $out/BUILD_TIME
      find "$out" -name .git -print0 | xargs -0 rm -rf
    '';
  };
  nativeBuildInputs = [git];

  vendorHash = "sha256-FNe+DQlJzDQLCEml1n8hri3nXfZe7IBUA/DE+dSQ9eo=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/leg100/otf/internal.Version=v${version}"
  ];

  preBuild = ''
    ldflags+=" -X github.com/leg100/otf/internal.Commit=$(cat COMMIT_HASH)"
    ldflags+=" -X github.com/leg100/otf/internal.Built=$(cat BUILD_TIME)"
  '';

  subPackages = [
    "cmd/otf"
    "cmd/otf-agent"
    "cmd/otfd"
  ];

  meta = with lib; {
    description = "An open source alternative to Terraform Enterprise.";
    license = licenses.mpl20;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
