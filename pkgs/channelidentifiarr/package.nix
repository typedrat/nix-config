{
  lib,
  python3Packages,
  fetchFromGitHub,
  makeWrapper,
}:
python3Packages.buildPythonApplication rec {
  pname = "channelidentifiarr";
  version = "0.6.5";

  src = fetchFromGitHub {
    owner = "egyptiangio";
    repo = "channelidentifiarr";
    tag = "v${version}";
    hash = "sha256-3KUqndnhXuUm3HUsp2T0BzL+e3gyNGljZ+Zb3bwsWDE=";
  };

  format = "other";

  nativeBuildInputs = [makeWrapper];

  propagatedBuildInputs = with python3Packages; [
    flask
    flask-cors
    gunicorn
    gevent
    requests
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/channelidentifiarr
    cp backend/app.py $out/lib/channelidentifiarr/
    cp backend/settings_manager.py $out/lib/channelidentifiarr/

    mkdir -p $out/lib/channelidentifiarr/frontend
    cp -r frontend/* $out/lib/channelidentifiarr/frontend/

    mkdir -p $out/bin
    makeWrapper ${python3Packages.gunicorn}/bin/gunicorn $out/bin/channelidentifiarr \
      --chdir $out/lib/channelidentifiarr \
      --prefix PYTHONPATH : $out/lib/channelidentifiarr \
      --add-flags "--bind \''${CHANNELIDENTIFIARR_BIND:-0.0.0.0:9192}" \
      --add-flags "--worker-class gevent" \
      --add-flags "--workers \''${CHANNELIDENTIFIARR_WORKERS:-2}" \
      --add-flags "--timeout \''${CHANNELIDENTIFIARR_TIMEOUT:-120}" \
      --add-flags "app:app"

    runHook postInstall
  '';

  doCheck = false;

  meta = {
    description = "Web-based TV channel lineup search and Dispatcharr/Emby integration";
    homepage = "https://github.com/egyptiangio/channelidentifiarr";
    license = lib.licenses.mit;
    mainProgram = "channelidentifiarr";
    platforms = lib.platforms.linux;
  };
}
