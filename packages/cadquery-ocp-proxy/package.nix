{
  lib,
  python3Packages,
  fetchFromGitHub,
  cadquery-ocp-novtk,
}:
# A do-nothing distribution whose only job is to carry the OCP version number,
# so `cadquery-ocp` and `cadquery-ocp-novtk` can never end up installed side by
# side. It lives in the build-system repo rather than getting its own release,
# so the version comes from the OCP release it tracks.
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "cadquery-ocp-proxy";

  # The bindings pin `cadquery-ocp-proxy==<their own version>`, so a version of
  # its own fails their runtime dependency check. PyPI carries proxy releases
  # for OCP versions that can't be built here yet, so there is no updateScript
  # either — bumping the bindings bumps this.
  inherit (cadquery-ocp-novtk) version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "CadQuery";
    repo = "ocp-build-system";
    rev = "69a56e2122d949c43fd2028e8754d20dc59b840c";
    hash = "sha256-tpSj2bG7MObY5b1OLudgLlgotMcOv4C56T4m50YNSvI=";
  };

  sourceRoot = "${finalAttrs.src.name}/cadquery_ocp_proxy";

  # Upstream stamps the two version strings from $VERSION at release time. The
  # uv_build ceiling is upstream pinning its release toolchain, not a real
  # incompatibility.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'version = "7.9.3.0"' 'version = "${finalAttrs.version}"' \
      --replace-fail '"uv_build>=0.9.7,<0.10.0"' '"uv_build"'
    substituteInPlace src/cadquery_ocp_proxy/_version.py \
      --replace-fail '__version__ = "7.8.1"' '__version__ = "${finalAttrs.version}"'
  '';

  build-system = with python3Packages; [
    uv-build
  ];

  pythonImportsCheck = [
    "cadquery_ocp_proxy"
  ];

  meta = {
    description = "Proxy package pinning the cadquery-ocp / cadquery-ocp-novtk version";
    homepage = "https://github.com/CadQuery/ocp-build-system";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [];
  };
})
