{
  lib,
  python3,
  fetchFromGitHub,
  nix-update-script,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "vast-cli";
  version = "1.4.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "vast-ai";
    repo = "vast-cli";
    tag = "v${version}";
    hash = "sha256-H3w1JsuCQTW032T+EBoCrRxtXoiAp7ke/aP8R0d0MeA=";
  };

  build-system = with python3.pkgs; [
    poetry-core
    # Derives the version from git tags at build time; its setup hook reads the
    # `version` attribute above and exports POETRY_DYNAMIC_VERSIONING_BYPASS,
    # so the build needs no VCS metadata.
    poetry-dynamic-versioning
  ];

  # Upstream pins several deps to exact versions (pillow, cryptography, pycares)
  # that nixpkgs has moved past; none reflect a real incompatibility. borb is
  # dropped entirely (see below), so relax its constraint too.
  pythonRelaxDeps = true;

  # borb (`borb~=2.1.25`) is only imported by the deprecated PDF-invoice module,
  # always inside a try/except that prints an install hint on failure. nixpkgs
  # only ships borb 3.x, whose build is currently broken on python3.14, so
  # dropping it keeps the CLI buildable while invoices degrade gracefully.
  pythonRemoveDeps = ["borb"];

  dependencies = with python3.pkgs; [
    aiodns
    aiohttp
    anyio
    argcomplete
    cryptography
    curlify
    pillow
    psutil
    pycares
    pycryptodome
    pyparsing
    python-dateutil
    requests
    rich
    urllib3
    xdg
  ];

  pythonImportsCheck = ["vastai"];

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "CLI and SDK for the Vast.ai GPU cloud service";
    homepage = "https://github.com/vast-ai/vast-cli";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [typedrat];
    mainProgram = "vastai";
  };
}
