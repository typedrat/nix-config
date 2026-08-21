{
  lib,
  python3Packages,
  fetchFromGitHub,
  lib3mf,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "lib3mf";
  version = "2.5.0";
  pyproject = true;

  # Upstream keeps the PyPI packaging (loader shim, generated ctypes bindings)
  # in its own repo, separate from the C++ library.
  src = fetchFromGitHub {
    owner = "3MFConsortium";
    repo = "lib3mf_python";
    tag = "v${finalAttrs.version}";
    hash = "sha256-N3eguLaUKw/uvikRFuIvEYGYAad5RZV6mV9Dvu9SfuI=";
  };

  # The repo vendors prebuilt libraries for all three platforms; swap the Linux
  # one for the build of the same release from source. Consumers resolve the
  # library relative to the package directory, so it has to sit inside it.
  postPatch = ''
    rm lib3mf/lib3mf.dll lib3mf/lib3mf.dylib lib3mf/lib3mf.so
    cp ${lib.getLib lib3mf}/lib/lib3mf.so lib3mf/lib3mf.so
    chmod u+w lib3mf/lib3mf.so
    echo 'include lib3mf/lib3mf.so' > MANIFEST.in

    # Python 3.14 deprecates the implicit MSVC-compatible layout that '_pack_'
    # selects on its own, and warns once per generated ctypes.Structure. The
    # structs are flat and byte-packed, so spelling out the layout '_pack_'
    # already implied silences the warnings without moving a single field.
    sed -i 's/^\(\s*\)_pack_ = \([0-9]\+\)$/\1_pack_ = \2\n\1_layout_ = "ms"/' lib3mf/Lib3MF.py
    [ "$(grep -c '^\s*_pack_ = ' lib3mf/Lib3MF.py)" = "$(grep -c '^\s*_layout_ = ' lib3mf/Lib3MF.py)" ]
  '';

  build-system = with python3Packages; [
    setuptools
  ];

  pythonImportsCheck = [
    "lib3mf"
  ];

  # Importing the package only locates the library; loading it through ctypes is
  # what proves the swapped-in build is usable.
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3Packages.python.interpreter} -c 'import lib3mf; assert lib3mf.get_wrapper().GetLibraryVersion() == (2, 5, 0)'
    runHook postInstallCheck
  '';

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Python bindings for lib3mf, the reference 3D Manufacturing Format implementation";
    homepage = "https://github.com/3MFConsortium/lib3mf_python";
    license = lib.licenses.bsd2;
    maintainers = with lib.maintainers; [];
    platforms = ["x86_64-linux"];
  };
})
