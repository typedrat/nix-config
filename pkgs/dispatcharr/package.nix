{
  lib,
  python3Packages,
  fetchFromGitHub,
  buildNpmPackage,
  ffmpeg,
  nodejs_24,
  streamlink,
}: let
  version = "0.15.1";

  src = fetchFromGitHub {
    owner = "Dispatcharr";
    repo = "Dispatcharr";
    tag = "v${version}";
    hash = "sha256-uehF55cywzuhuh3LLT+rTTLAJwSb3IIuUJOLKq35tcA=";
    leaveDotGit = true;
  };

  frontend = buildNpmPackage {
    pname = "dispatcharr-frontend";
    inherit version src;

    sourceRoot = "${src.name}/frontend";

    nodejs = nodejs_24;

    # Peer dependency conflicts with React 19 vs packages expecting React 16-18
    npmFlags = ["--legacy-peer-deps"];

    npmDepsHash = "sha256-9g7Uts6tOHZppSkqI5QjYBgxAHtgz8xKnqUnKzBtMYo=";
    forceGitDeps = true;
    makeCacheWritable = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/* $out/
      runHook postInstall
    '';
  };
in
  python3Packages.buildPythonApplication {
    pname = "dispatcharr";
    inherit version src;

    pyproject = true;

    postPatch = ''
            cp ${./pyproject.toml} pyproject.toml
            cp ${./manage.py} dispatcharr/manage.py

            # Patch settings.py to read paths from environment variables
            substituteInPlace dispatcharr/settings.py \
              --replace-fail \
                'STATIC_ROOT = BASE_DIR / "static"' \
                'STATIC_ROOT = Path(os.environ.get("STATIC_ROOT", BASE_DIR / "static"))' \
              --replace-fail \
                'STATICFILES_DIRS = [
          os.path.join(BASE_DIR, "frontend/dist"),  # React build static files
      ]' \
                'STATICFILES_DIRS = [os.environ.get("STATICFILES_DIRS", os.path.join(BASE_DIR, "frontend/dist"))]' \
              --replace-fail \
                'MEDIA_ROOT = BASE_DIR / "media"' \
                'MEDIA_ROOT = Path(os.environ.get("MEDIA_ROOT", BASE_DIR / "media"))' \
              --replace-fail \
                '"DIRS": [os.path.join(BASE_DIR, "frontend/dist"), BASE_DIR / "templates"],' \
                '"DIRS": [os.environ.get("TEMPLATE_DIRS", os.path.join(BASE_DIR, "frontend/dist")), BASE_DIR / "templates"],' \
              --replace-fail \
                '"django.middleware.security.SecurityMiddleware",' \
                '"django.middleware.security.SecurityMiddleware",
          "whitenoise.middleware.WhiteNoiseMiddleware",'

            # Add URL pattern to serve /assets/ from frontend
            substituteInPlace dispatcharr/urls.py \
              --replace-fail \
                'from django.views.generic import TemplateView, RedirectView' \
                'from django.views.generic import TemplateView, RedirectView
      from django.views.static import serve
      import os' \
              --replace-fail \
                '# Catch-all routes should always be last' \
                '# Serve frontend assets
          re_path(r"^assets/(?P<path>.*)$", serve, {"document_root": os.environ.get("STATICFILES_DIRS", "frontend/dist") + "/assets"}),
          re_path(r"^(?P<path>logo\.png|favicon\.ico|vite\.svg)$", serve, {"document_root": os.environ.get("STATICFILES_DIRS", "frontend/dist")}),
          # Catch-all routes should always be last'
    '';

    build-system = with python3Packages; [setuptools];

    dependencies = with python3Packages; [
      django
      djangorestframework
      djangorestframework-simplejwt
      django-cors-headers
      django-filter
      drf-yasg
      django-celery-beat
      channels
      channels-redis
      daphne
      psycopg2
      celery
      redis
      requests
      gevent
      yt-dlp
      pillow
      torch
      sentence-transformers
      lxml
      m3u8
      rapidfuzz
      regex
      tzlocal
      psutil
      whitenoise
    ];

    nativeBuildInputs = [
      ffmpeg
      streamlink
    ];

    makeWrapperArgs = [
      "--prefix PATH : ${lib.makeBinPath [
        ffmpeg
        streamlink
      ]}"
    ];

    postInstall = ''
      mkdir -p $out/share/dispatcharr
      cp -r ${frontend} $out/share/dispatcharr/frontend

      # Create wrapper scripts for daphne and celery with full PYTHONPATH from build environment
      makeWrapper ${python3Packages.daphne}/bin/daphne $out/bin/dispatcharr-daphne \
        --set PYTHONPATH "$PYTHONPATH:$out/${python3Packages.python.sitePackages}"
      makeWrapper ${python3Packages.celery}/bin/celery $out/bin/dispatcharr-celery \
        --set PYTHONPATH "$PYTHONPATH:$out/${python3Packages.python.sitePackages}"
    '';

    doCheck = false;

    meta = {
      description = "IPTV stream management and dispatching application";
      homepage = "https://github.com/Dispatcharr/Dispatcharr";
      license = lib.licenses.gpl3Only;
      mainProgram = "dispatcharr";
      platforms = lib.platforms.linux;
    };
  }
