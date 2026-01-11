{
  config,
  inputs',
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  openrgb = inputs'.nanopkgs.packages.openrgb.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        # Add support for MSI MPG X870I EDGE TI EVO WIFI (MS-7E50)
        # https://gitlab.com/CalcProgrammer1/OpenRGB/-/merge_requests/3154
        # Adapted for nanopkgs OpenRGB revision
        (pkgs.writeText "msi-x870i-support.patch" ''
          diff --git a/Controllers/MSIMysticLightController/MSIMysticLight761Controller/MSIMysticLight761Controller.cpp b/Controllers/MSIMysticLightController/MSIMysticLight761Controller/MSIMysticLight761Controller.cpp
          --- a/Controllers/MSIMysticLightController/MSIMysticLight761Controller/MSIMysticLight761Controller.cpp
          +++ b/Controllers/MSIMysticLightController/MSIMysticLight761Controller/MSIMysticLight761Controller.cpp
          @@ -57,6 +57,7 @@ static const std::string board_names[] =
               "MSI Z890 GAMING PLUS WIFI (MS-7E34)",
               "MSI X870E GAMING PLUS WIFI (MS-7E70)",
               "MSI MAG X870E TOMAHAWK WIFI (MS-7E59)",
          +    "MSI MPG X870I EDGE TI EVO WIFI (MS-7E50)",
           };

           static const mystic_light_761_config board_configs[] =
          @@ -71,6 +72,7 @@ static const mystic_light_761_config board_configs[] =
               { &(board_names[7]), 0,  0,  0, 1, &zone_set1,  MSIMysticLight761Controller::DIRECT_MODE_ZONE_BASED },    // MSI Z890 GAMING PLUS WIFI
               { &(board_names[8]), 0,  0,  0, 1, &zone_set1,  MSIMysticLight761Controller::DIRECT_MODE_ZONE_BASED },    // MSI X870E GAMING PLUS WIFI
               { &(board_names[9]), 0,  0,  0, 1, &zone_set1,  MSIMysticLight761Controller::DIRECT_MODE_ZONE_BASED },    // MSI MAG X870E TOMAHAWK WIFI
          +    { &(board_names[10]), 0,  0,  0, 1, &zone_set1,  MSIMysticLight761Controller::DIRECT_MODE_ZONE_BASED },   // MSI MPG X870I EDGE TI EVO WIFI

           };
        '')
      ];
  });
in {
  options.rat.hardware.openrgb.enable = mkEnableOption "OpenRGB";

  config = mkIf config.rat.hardware.openrgb.enable {
    services.hardware.openrgb = {
      enable = true;
      package = openrgb;
    };

    programs.coolercontrol.enable = true;

    boot.kernelModules = ["i2c-dev"];
  };
}
