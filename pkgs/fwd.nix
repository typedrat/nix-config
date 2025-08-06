{
  lib,
  fetchgit,
  rustPlatform,
  gitMinimal,
}:
rustPlatform.buildRustPackage {
  pname = "fwd";
  version = "0.9.1";

  src = fetchgit {
    url = "https://github.com/DeCarabas/fwd.git";
    rev = "df914e68f21cf93edad4b051230d6ed97128c611";
    hash = "sha256-z/9jMyJx9y9Mt0yfsa7IfdGeOqI0rVJyqPcgU3nCcZI=";
    leaveDotGit = true;
  };

  cargoHash = "sha256-Mw0MKmI/wZjrsUWBE+9nsuX5KwG0kY+ORe436vjs6rs=";

  nativeBuildInputs = [
    gitMinimal
  ];

  meta = with lib; {
    description = "A port-forwarding utility.";
    homepage = "https://github.com/DeCarabas/fwd";
    license = licenses.mit;
    maintainers = [];
  };
}
