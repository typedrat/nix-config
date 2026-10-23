{
  lib,
  python3Packages,
  ghidra,
}:
python3Packages.buildPythonPackage {
  pname = "ghidra-stubs";

  # The Ghidra build generates these stubs from its own sources and ships the
  # wheel in its docs, so they always describe the installed Ghidra's API.
  # There's nothing to update independently, so the updateScript
  # buildPythonPackage supplies by default is cleared.
  inherit (ghidra) version;
  format = "wheel";
  src = "${ghidra}/lib/ghidra/docs/ghidra_stubs/ghidra_stubs-${ghidra.version}-py3-none-any.whl";

  passthru.updateScript = null;

  meta = {
    description = "PEP 561 type stubs for the Ghidra API";
    homepage = "https://github.com/NationalSecurityAgency/ghidra";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [];
  };
}
