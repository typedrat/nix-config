# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    nodejs_22 = prev.nodejs_22.overrideAttrs (oldAttrs: {
      patches =
        (oldAttrs.patches or [])
        ++ [
          (prev.writeTextFile {
            name = "nodejs-fix-ucs2-detection.patch";
            text = ''
              --- a/test/parallel/test-fs-readdir-ucs2.js
              +++ b/test/parallel/test-fs-readdir-ucs2.js
              @@ -19,7 +19,7 @@
               try {
                 fs.closeSync(fs.openSync(fullpath, 'w+'));
               } catch (e) {
              -  if (e.code === 'EINVAL')
              +  if (e.code === 'EINVAL' || e.code === 'EILSEQ')
                   common.skip('test requires filesystem that supports UCS2');
                 throw e;
               }
            '';
          })
        ];
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
