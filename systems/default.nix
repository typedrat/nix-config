{
  lib,
  self,
  inputs,
  ...
}: let
  additionalClasses = {
    wsl = "nixos";
  };

  normaliseClass = class: additionalClasses.${class} or class;
in {
  imports = [
    inputs.easy-hosts.flakeModule
  ];

  easy-hosts = {
    shared.modules = [
      ../users
    ];

    inherit additionalClasses;

    perClass = class: let
      normalisedClass = normaliseClass class;
    in {
      modules = builtins.concatLists [
        [
          "${self}/modules/${normalisedClass}"
        ]

        (lib.optionals (normalisedClass == "nixos") [
          inputs.home-manager.nixosModules.home-manager
        ])

        (lib.optionals (class == "wsl") [
          inputs.nixos-wsl.nixosModules.default
        ])
      ];
    };

    hosts = {
      hyperion = {
        arch = "x86_64";
        class = "nixos";
      };
    };
  };
}
