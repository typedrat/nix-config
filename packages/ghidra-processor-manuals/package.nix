{
  lib,
  fetchurl,
  linkFarm,
}: let
  # Ghidra's instruction index files point at page numbers, so each PDF has to
  # be the exact revision its index names. Newer editions from the vendor
  # would open at the wrong page, which is also why there's no updateScript.
  manuals = lib.importJSON ./manuals.json;
in
  lib.addMetaAttrs {
    description = "Processor reference manuals that Ghidra's instruction lookup expects but doesn't ship";
    platforms = lib.platforms.all;
  } (linkFarm "ghidra-processor-manuals" (map (m: {
      name = "lib/ghidra/Ghidra/Processors/${m.processor}/data/manuals/${m.filename}";
      path = fetchurl {
        inherit (m) urls hash;
        name = m.filename;
      };
    })
    manuals))
