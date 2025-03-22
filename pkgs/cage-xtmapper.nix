{
  lib,
  fetchFromGitHub,
  cage,
  wlroots,
  writeShellScriptBin,
}: let
  cage-xtmapper = fetchFromGitHub {
    owner = "Xtr126";
    repo = "cage-xtmapper";
    rev = "v0.2.0";
    hash = "sha256-Bfe9EaKcZwHjHB//k+sDz+lPYR+br3eag35LtnZOJ9U=";
  };

  wlroots_patched =
    (wlroots.override {
      enableXWayland = false;
    })
    .overrideAttrs (orig: {
      pname = "wlroots-xtmapper";

      patches =
        (orig.patches or [])
        ++ [
          "${cage-xtmapper}/wlroots_patches/0001-confine-pointer.patch"
          "${cage-xtmapper}/wlroots_patches/0002-add-environment-variable-for-disabling-title-bar.patch"
          "${cage-xtmapper}/wlroots_patches/0003-wlroots-wayland-backend-custom-size.patch"
          "${cage-xtmapper}/wlroots_patches/0004-wlroots-x11-backend-custom-size.patch"
        ];
    });

  cage_patched =
    (cage.override {
      wlroots = wlroots_patched;
    })
    .overrideAttrs (orig: {
      pname = "cage-xtmapper";

      patches =
        (orig.patches or [])
        ++ [
          "${cage-xtmapper}/0002-feat-print-keyboard-and-mouse-keys.patch"
          "${cage-xtmapper}/0003-disable-Xwayland.patch"
          "${cage-xtmapper}/0004-fix-set-line-buffering.patch"
          "${cage-xtmapper}/0005-Add-toggle-key.patch"
          "${cage-xtmapper}/0007-fix-build-Remove-all-session-dependent-code.patch"
        ];
    });
in
  (writeShellScriptBin "cage-xtmapper" ''
    if [ "$(id -u)" != "0" ]; then
    	echo "This script requires root access to access waydroid shell."
    	exit 1
    fi

    if [ $# -eq 0 ]; then
    	echo "User not specified."
    	exit 1
    fi

    while [ $# -gt 0 ]; do
      case "$1" in
        --user)
          shift
          user="$1"
          ;;
        --window-width)
          shift
          XTMAPPER_WIDTH="$1"
          ;;
        --window-height)
          shift
          XTMAPPER_HEIGHT="$1"
          ;;
        --window-no-title-bar)
          shift
          export WLR_NO_DECORATION=1
          ;;
        *)
          echo "Invalid argument"
          exit 1
          ;;
      esac
      shift
    done

    export XTMAPPER_WIDTH=''${XTMAPPER_WIDTH:-1280}
    export XTMAPPER_HEIGHT=''${XTMAPPER_HEIGHT:-720}

    waydroid container stop
    systemctl restart waydroid-container.service

    su "$user" --command "${lib.getExe cage_patched} -- waydroid show-full-ui" | (
      while [[ -z $(waydroid shell getprop sys.boot_completed) ]]; do
      	sleep 1;
      done;

      waydroid shell -- sh -c 'test -d /data/media/0/Android/data/xtr.keymapper/files/xtMapper.sh || mkdir -p /data/media/0/Android/data/xtr.keymapper/files/'
      echo 'exec /system/bin/app_process -Djava.library.path=$(echo /data/app/*/xtr.keymapper*/lib/x86_64) -Djava.class.path=$(echo /data/app/*/xtr.keymapper*/base.apk) / xtr.keymapper.server.RemoteServiceShell "$@"' |\
          waydroid shell -- sh -c 'test -f /data/media/0/Android/data/xtr.keymapper/files/xtMapper.sh || exec cat > /data/media/0/Android/data/xtr.keymapper/files/xtMapper.sh'
      exec waydroid shell -- sh /data/media/0/Android/data/xtr.keymapper/files/xtMapper.sh --wayland-client
    )
  '')
  // {
    cage = cage_patched;
    wlroots = wlroots_patched;
  }
