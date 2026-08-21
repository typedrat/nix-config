{
  lib,
  python3Packages,
  fetchzip,
  fetchFromGitHub,
  cmake,
  ninja,
  fmt,
  rapidjson,
  opencascade-occt,
  cadquery-ocp-proxy,
  freetype,
  fontconfig,
  libGL,
  libGLU,
  libx11,
  libxext,
  libxi,
  libxmu,
  tcl,
  tk,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "cadquery-ocp-novtk";
  version = "7.9.3.1.1";
  pyproject = true;

  # The bindings are machine-written by pywrap, which needs a clang 21 with
  # Python bindings plus a pile of conda-only tooling. Upstream's own release
  # pipeline skips that step and compiles the generated C++ attached to each
  # tag, so this does the same.
  src = fetchzip {
    url = "https://github.com/CadQuery/OCP/releases/download/${finalAttrs.version}/OCP_src_stubs_Linux.zip";
    hash = "sha256-gfZFv/evrLHX5TSjAmc6ap45nCbAuNUGkb989BrfqhY=";
  };

  # Upstream's wheel scaffolding: pyproject.toml, the OCP/__init__.py shim and
  # ocp-tree.py, which walks the compiled module to lay out the submodule
  # packages that make `import OCP.gp` work.
  buildSystemSrc = fetchFromGitHub {
    owner = "CadQuery";
    repo = "ocp-build-system";
    rev = "69a56e2122d949c43fd2028e8754d20dc59b840c";
    hash = "sha256-tpSj2bG7MObY5b1OLudgLlgotMcOv4C56T4m50YNSvI=";
  };

  # The novtk variant: drop the IVtk* bindings so the module links against OCCT
  # alone and nothing drags in VTK. Deleting the whole target_link_libraries
  # line the way upstream's sed does would take pybind11 and fmt with it, so
  # the VTK targets come out by name instead.
  postPatch = ''
    rm IVtk*.cpp IVtk*.hxx vtk_pybind.h
    sed -i '/register_IVtk/d' OCP.cpp
    sed -i \
      -e '/^find_package( VTK REQUIRED/,/^)$/d' \
      -e '/^message(STATUS "VTK ''${VTK_VERSION} found")$/d' \
      CMakeLists.txt
    substituteInPlace CMakeLists.txt \
      --replace-fail " VTK::WrappingPythonCore VTK::RenderingCore VTK::CommonDataModel VTK::CommonExecutionModel" ""
  '';

  nativeBuildInputs = [
    cmake
    ninja
  ];

  # cmake is driven by hand below; its setup hook would otherwise hijack the
  # configure phase and leave the wheel build with nothing to package.
  dontUseCmakeConfigure = true;

  buildInputs = [
    opencascade-occt
    fmt
    rapidjson
    python3Packages.pybind11
    freetype
    fontconfig
    libGL
    libGLU
    libx11
    libxext
    libxi
    libxmu
    tcl
    tk
  ];

  build-system = with python3Packages; [
    setuptools
  ];

  dependencies = [
    cadquery-ocp-proxy
  ];

  preBuild = ''
    cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_CXX_FLAGS="-DFMT_HEADER_ONLY -fvisibility=hidden -w" \
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
      -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
      -DCMAKE_INSTALL_RPATH="${lib.getLib opencascade-occt}/lib;${lib.getLib fmt}/lib"
    ninja -C build -j "$NIX_BUILD_CORES"

    wheelSrc="$NIX_BUILD_TOP/wheel"
    cp -r ${finalAttrs.buildSystemSrc}/pypi "$wheelSrc"
    chmod -R u+w "$wheelSrc"
    cp build/OCP*.so "$wheelSrc/"
    cd "$wheelSrc"

    substituteInPlace pyproject.toml \
      --replace-fail 'name = "cadquery-ocp"' 'name = "cadquery-ocp-novtk"' \
      --replace-fail 'version = "0.0.0.0"' 'version = "${finalAttrs.version}"' \
      --replace-fail 'cadquery-ocp-proxy==0.0.0.0' 'cadquery-ocp-proxy==${finalAttrs.version}'

    # Imports the freshly built module, so it has to run after the .so lands
    # next to it and before the .so is moved into the package directory.
    python ocp-tree.py
    mv OCP*.so OCP/
  '';

  pythonImportsCheck = [
    "OCP"
    "OCP.gp"
    "OCP.BRepPrimAPI"
    "OCP.STEPControl"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Python wrapper for the OpenCASCADE Technology 3D geometry kernel, without VTK";
    homepage = "https://github.com/CadQuery/OCP";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [];
    platforms = lib.platforms.linux;
  };
})
