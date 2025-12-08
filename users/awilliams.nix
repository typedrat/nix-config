{pkgs, ...}: {
  rat.users.awilliams = {
    uid = 1000;
    isNormalUser = true;
    home = "/home/awilliams";
    extraGroups = [
      "dialout"
      "games"
      "wheel"
    ];
    shell = pkgs.zsh;
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFCm+qnsWUuTDU6IgvxPAkfe6dnwwomGQXlM9c2yUqlJ awilliams@hyperion"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBjz3PWnehAKNKXGpkDu+Huiyizd/24efmLmJCoct+KP awilliams@hyperion-windows"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLI5a9axsIGCRFLzb9lviLINzebCWV68O94WlXRnMkEKO8uqLAJHGy2aw8i/rB4TcLfqP5lBvOZn0nCNRTvZIRg= awilliams@ipad"
    ];

    cli.enable = true;
    theming.enable = true;

    # Git configuration
    git = {
      name = "Alexis Williams";
      email = "alexis@typedr.at";
    };

    # Email accounts
    email.accounts = {
      Personal = {
        address = "alexis@typedr.at";
        realName = "Alexis Williams";
        primary = true;
        flavor = "gmail.com";
      };

      Backup = {
        address = "typedrat@gmail.com";
        realName = "Alexis Williams";
        flavor = "gmail.com";
      };

      Work = {
        address = "alexis@synapdeck.com";
        realName = "Alexis Williams";
        flavor = "gmail.com";
      };
    };

    # Rclone remotes
    rclone.remotes = {
      b2 = {
        type = "b2";
        config = {};
        secrets = {
          # Secret names that will be resolved to paths by the home-manager module
          account = "b2/keyId";
          key = "b2/applicationKey";
        };
      };

      workdrive = {
        type = "drive";
        config = {
          service_account_file = "work-gdrive-sa-key";
          impersonate = "alexis@synapdeck.com";
          scope = "drive";
        };
      };

      workdrive-shared = {
        type = "drive";
        config = {
          service_account_file = "work-gdrive-sa-key";
          impersonate = "alexis@synapdeck.com";
          scope = "drive";
          team_drive = "0AEjPQYC7XEWcUk9PVA";
        };
      };

      iserlohn = {
        type = "sftp";
        config = {
          host = "iserlohn.lan";
          user = "awilliams";
          key_file = "id_ed25519";
        };
      };

      iserlohn-media = {
        type = "alias";
        config = {
          remote = "iserlohn:/mnt/media";
        };

        mount = {
          enable = true;
          path = "mnt/iserlohn-media";
        };
      };
    };

    # Environment variables
    environment.variables = {
      VIZIO_IP = "viziocastdisplay.lan";
      VIZIO_AUTH = "Zmge7tbkiz";
    };

    mime = {
      enable = true;
      defaultApplications = {
        # Document formats
        "application/pdf" = "org.kde.okular.desktop";
        "application/postscript" = "org.kde.okular.desktop";
        "application/eps" = "org.kde.okular.desktop";
        "image/x-eps" = "org.kde.okular.desktop";
        "image/vnd.djvu" = "org.kde.okular.desktop";
        "image/x-djvu" = "org.kde.okular.desktop";
        "application/epub+zip" = "org.kde.okular.desktop";

        # Text and source code
        "text/plain" = "dev.zed.Zed.desktop";
        "text/x-log" = "dev.zed.Zed.desktop";
        "text/x-readme" = "dev.zed.Zed.desktop";
        "text/markdown" = "dev.zed.Zed.desktop";
        "text/x-markdown" = "dev.zed.Zed.desktop";

        # Web browser
        "text/html" = "zen-beta.desktop";
        "application/xhtml+xml" = "zen-beta.desktop";
        "x-scheme-handler/http" = "zen-beta.desktop";
        "x-scheme-handler/https" = "zen-beta.desktop";
        "x-scheme-handler/about" = "zen-beta.desktop";
        "x-scheme-handler/unknown" = "zen-beta.desktop";

        # Web languages
        "text/css" = "dev.zed.Zed.desktop";
        "text/javascript" = "dev.zed.Zed.desktop";
        "application/javascript" = "dev.zed.Zed.desktop";
        "application/x-javascript" = "dev.zed.Zed.desktop";
        "application/typescript" = "dev.zed.Zed.desktop";
        "application/json" = "dev.zed.Zed.desktop";
        "application/x-json" = "dev.zed.Zed.desktop";

        # Programming languages
        "text/x-python" = "dev.zed.Zed.desktop";
        "text/x-python3" = "dev.zed.Zed.desktop";
        "application/x-python" = "dev.zed.Zed.desktop";
        "text/x-rust" = "dev.zed.Zed.desktop";
        "text/rust" = "dev.zed.Zed.desktop";
        "text/x-go" = "dev.zed.Zed.desktop";
        "text/x-java" = "dev.zed.Zed.desktop";
        "text/x-c" = "dev.zed.Zed.desktop";
        "text/x-c++" = "dev.zed.Zed.desktop";
        "text/x-c++hdr" = "dev.zed.Zed.desktop";
        "text/x-c++src" = "dev.zed.Zed.desktop";
        "text/x-chdr" = "dev.zed.Zed.desktop";
        "text/x-csrc" = "dev.zed.Zed.desktop";
        "text/x-ruby" = "dev.zed.Zed.desktop";
        "text/x-php" = "dev.zed.Zed.desktop";
        "text/x-csharp" = "dev.zed.Zed.desktop";
        "text/x-scala" = "dev.zed.Zed.desktop";
        "text/x-kotlin" = "dev.zed.Zed.desktop";
        "text/x-swift" = "dev.zed.Zed.desktop";

        # Shell scripts
        "text/x-sh" = "dev.zed.Zed.desktop";
        "text/x-shellscript" = "dev.zed.Zed.desktop";
        "application/x-sh" = "dev.zed.Zed.desktop";
        "application/x-shellscript" = "dev.zed.Zed.desktop";
        "text/x-bash" = "dev.zed.Zed.desktop";
        "text/x-zsh" = "dev.zed.Zed.desktop";

        # Configuration files
        "application/xml" = "dev.zed.Zed.desktop";
        "text/xml" = "dev.zed.Zed.desktop";
        "application/x-yaml" = "dev.zed.Zed.desktop";
        "text/yaml" = "dev.zed.Zed.desktop";
        "text/x-yaml" = "dev.zed.Zed.desktop";
        "application/toml" = "dev.zed.Zed.desktop";
        "text/toml" = "dev.zed.Zed.desktop";
        "application/x-toml" = "dev.zed.Zed.desktop";
        "text/x-ini" = "dev.zed.Zed.desktop";
        "text/x-config" = "dev.zed.Zed.desktop";

        # Nix
        "text/x-nix" = "dev.zed.Zed.desktop";

        # Video formats
        "video/mp4" = "mpv.desktop";
        "video/x-matroska" = "mpv.desktop";
        "video/webm" = "mpv.desktop";
        "video/mpeg" = "mpv.desktop";
        "video/x-msvideo" = "mpv.desktop";
        "video/quicktime" = "mpv.desktop";
        "video/x-flv" = "mpv.desktop";
        "video/x-m4v" = "mpv.desktop";
        "video/3gpp" = "mpv.desktop";
        "video/3gpp2" = "mpv.desktop";
        "video/ogg" = "mpv.desktop";
        "video/x-ogm" = "mpv.desktop";
        "video/x-theora" = "mpv.desktop";
        "video/mp2t" = "mpv.desktop";
        "video/vnd.mpegurl" = "mpv.desktop";
        "video/x-ms-wmv" = "mpv.desktop";
        "video/x-ms-asf" = "mpv.desktop";
        "video/x-flc" = "mpv.desktop";
        "video/x-flic" = "mpv.desktop";
        "application/vnd.rn-realmedia" = "mpv.desktop";
        "application/x-matroska" = "mpv.desktop";

        # Audio formats
        "audio/mpeg" = "mpv.desktop";
        "audio/mp3" = "mpv.desktop";
        "audio/mp4" = "mpv.desktop";
        "audio/x-m4a" = "mpv.desktop";
        "audio/flac" = "mpv.desktop";
        "audio/x-flac" = "mpv.desktop";
        "audio/ogg" = "mpv.desktop";
        "audio/x-vorbis+ogg" = "mpv.desktop";
        "audio/x-opus+ogg" = "mpv.desktop";
        "audio/opus" = "mpv.desktop";
        "audio/x-wav" = "mpv.desktop";
        "audio/wav" = "mpv.desktop";
        "audio/aac" = "mpv.desktop";
        "audio/x-aac" = "mpv.desktop";
        "audio/webm" = "mpv.desktop";
        "audio/x-matroska" = "mpv.desktop";
        "audio/x-ape" = "mpv.desktop";
        "audio/x-wavpack" = "mpv.desktop";
        "audio/x-tta" = "mpv.desktop";
        "audio/x-ms-wma" = "mpv.desktop";
        "application/ogg" = "mpv.desktop";

        # Common raster formats
        "image/jpeg" = "org.nomacs.ImageLounge.desktop";
        "image/png" = "org.nomacs.ImageLounge.desktop";
        "image/gif" = "org.nomacs.ImageLounge.desktop";
        "image/bmp" = "org.nomacs.ImageLounge.desktop";
        "image/x-bmp" = "org.nomacs.ImageLounge.desktop";
        "image/x-ms-bmp" = "org.nomacs.ImageLounge.desktop";
        "image/tiff" = "org.nomacs.ImageLounge.desktop";
        "image/webp" = "org.nomacs.ImageLounge.desktop";
        "image/vnd.wap.wbmp" = "org.nomacs.ImageLounge.desktop";

        # Modern formats
        "image/avif" = "org.nomacs.ImageLounge.desktop";
        "image/heif" = "org.nomacs.ImageLounge.desktop";
        "image/heic" = "org.nomacs.ImageLounge.desktop";
        "image/jxl" = "org.nomacs.ImageLounge.desktop";

        # Vector formats
        "image/svg+xml" = "org.nomacs.ImageLounge.desktop";

        # Icon formats
        "image/vnd.microsoft.icon" = "org.nomacs.ImageLounge.desktop";
        "image/x-icon" = "org.nomacs.ImageLounge.desktop";
        "image/x-ico" = "org.nomacs.ImageLounge.desktop";
        "image/x-icns" = "org.nomacs.ImageLounge.desktop";

        # JPEG variants
        "image/jp2" = "org.nomacs.ImageLounge.desktop";
        "image/jpx" = "org.nomacs.ImageLounge.desktop";
        "image/jpm" = "org.nomacs.ImageLounge.desktop";

        # Portable formats
        "image/x-portable-bitmap" = "org.nomacs.ImageLounge.desktop";
        "image/x-portable-graymap" = "org.nomacs.ImageLounge.desktop";
        "image/x-portable-pixmap" = "org.nomacs.ImageLounge.desktop";
        "image/x-xbitmap" = "org.nomacs.ImageLounge.desktop";
        "image/x-xpixmap" = "org.nomacs.ImageLounge.desktop";

        # Other formats
        "image/x-tga" = "org.nomacs.ImageLounge.desktop";
        "image/x-pcx" = "org.nomacs.ImageLounge.desktop";
        "image/x-sgi" = "org.nomacs.ImageLounge.desktop";
        "image/vnd-ms.dds" = "org.nomacs.ImageLounge.desktop";
        "image/x-exr" = "org.nomacs.ImageLounge.desktop";
        "image/x-xcf" = "org.nomacs.ImageLounge.desktop";

        # Adobe and professional formats
        "image/vnd.adobe.photoshop" = "org.nomacs.ImageLounge.desktop";
        "image/x-psd" = "org.nomacs.ImageLounge.desktop";

        # Krita
        "application/x-krita" = "org.nomacs.ImageLounge.desktop";

        # RAW formats - Canon
        "image/x-canon-cr2" = "org.nomacs.ImageLounge.desktop";
        "image/x-canon-cr3" = "org.nomacs.ImageLounge.desktop";
        "image/x-canon-crw" = "org.nomacs.ImageLounge.desktop";

        # RAW formats - Nikon
        "image/x-nikon-nef" = "org.nomacs.ImageLounge.desktop";
        "image/x-nikon-nrw" = "org.nomacs.ImageLounge.desktop";

        # RAW formats - Sony
        "image/x-sony-arw" = "org.nomacs.ImageLounge.desktop";
        "image/x-sony-sr2" = "org.nomacs.ImageLounge.desktop";
        "image/x-sony-srf" = "org.nomacs.ImageLounge.desktop";

        # RAW formats - Olympus
        "image/x-olympus-orf" = "org.nomacs.ImageLounge.desktop";

        # RAW formats - Pentax
        "image/x-pentax-pef" = "org.nomacs.ImageLounge.desktop";

        # RAW formats - Panasonic
        "image/x-panasonic-raw" = "org.nomacs.ImageLounge.desktop";
        "image/x-panasonic-rw2" = "org.nomacs.ImageLounge.desktop";

        # RAW formats - Fujifilm
        "image/x-fuji-raf" = "org.nomacs.ImageLounge.desktop";

        # RAW formats - Other manufacturers
        "image/x-adobe-dng" = "org.nomacs.ImageLounge.desktop";
        "image/x-minolta-mrw" = "org.nomacs.ImageLounge.desktop";
        "image/x-samsung-srw" = "org.nomacs.ImageLounge.desktop";
        "image/x-sigma-x3f" = "org.nomacs.ImageLounge.desktop";
        "image/x-kodak-dcr" = "org.nomacs.ImageLounge.desktop";
        "image/x-kodak-k25" = "org.nomacs.ImageLounge.desktop";
        "image/x-kodak-kdc" = "org.nomacs.ImageLounge.desktop";
      };
    };
  };
}
