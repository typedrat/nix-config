{
  python3Packages,
  fetchFromGitHub,
  fetchPypi,
  calibre,
  nodejs,
}: let
  ascii = python3Packages.buildPythonPackage rec {
    pname = "ascii";
    version = "3.6";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-tf/EyyCsF4nKyAqRMZNF8mo+jzxtb+/zoiDBtsUFYUE=";
    };

    dependencies = with python3Packages; [
      pillow
      urllib3
    ];
  };

  pyease-grpc = python3Packages.buildPythonPackage rec {
    pname = "pyease-grpc";
    version = "1.7.0";

    src = fetchFromGitHub {
      owner = "dipu-bd";
      repo = "pyease-grpc";
      rev = "v${version}";
      hash = "sha256-IE6Dryqz4wcoTbHv0HMhVYH99iq2KPYCjWhC+usc2aQ=";
    };

    dependencies = with python3Packages; [
      requests
      protobuf
      grpcio
    ];
  };

  PyExecJS = python3Packages.buildPythonPackage rec {
    pname = "PyExecJS";
    version = "1.5.1";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-NMwdBwl2kYGD/3vcCtcfgVeokcknCMAMX7v/enafUFw=";
    };

    dependencies = with python3Packages; [
      nodejs
      six
    ];
  };
in
  python3Packages.buildPythonApplication rec {
    pname = "lightnovel-crawler";
    version = "3.7.5";

    src = fetchFromGitHub {
      owner = "dipu-bd";
      repo = "lightnovel-crawler";
      rev = "v${version}";
      hash = "sha256-aYnx+t8DkSty9Kdz+NxYEQWiMFpJ6/5xWNpKkvcnkR8=";
    };

    dependencies = with python3Packages; [
      calibre
      ascii
      regex
      packaging
      pyease-grpc
      python-dotenv
      beautifulsoup4
      requests
      python-slugify
      colorama
      tqdm
      PyExecJS
      ebooklib
      pillow
      cloudscraper
      lxml
      lxml-html-clean
      readability-lxml
      questionary
      prompt-toolkit
      html5lib
      base58
      python-box
      pycryptodome
      selenium
    ];

    doCheck = false;

    meta = {
      description = "Generate and download e-books from online sources.";
      homepage = "https://github.com/dipu-bd/lightnovel-crawler";
    };
  }
