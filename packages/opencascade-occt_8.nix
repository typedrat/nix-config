{
  fetchFromGitHub,
  opencascade-occt,
}:
# OCP 8's generated bindings compile against OCCT 8's headers, while nixpkgs'
# opencascade-occt is 7.9.3 for its other consumers — so this sits beside it
# instead of overriding it, which would rebuild all of them. No updateScript:
# the version has to follow whatever OCCT the OCP release was generated
# against, not the newest one available.
opencascade-occt.overrideAttrs {
  version = "8.0.1";

  src = fetchFromGitHub {
    owner = "Open-Cascade-SAS";
    repo = "OCCT";
    tag = "V8_0_1";
    hash = "sha256-QgSfrWc6qxbiHBapyGa9+ixRi/dOXqMox8U2f+tCH8o=";
  };

  # Inherited from the 7.9.3 expression, where it override-builds *that*
  # version with VTK; keeping it here would quietly test the wrong package.
  passthru = {};
}
