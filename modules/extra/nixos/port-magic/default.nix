{
  config,
  lib,
  ...
}:
with lib; {
  options.links = mkOption {
    type = types.attrsOf (types.submodule ./link.nix);
    description = "Port Magic links.";
    default = {};
  };

  config = {
    assertions = [
      {
        assertion = let
          # Create list of name+port tuples
          portAssignments =
            mapAttrsToList (name: link: {
              inherit name;
              inherit (link) port;
            })
            config.links;

          # Group by port number
          byPort = groupBy (x: toString x.port) portAssignments;

          # Filter to only the ports with multiple assignments
          conflicts = filterAttrs (_port: assignments: length assignments > 1) byPort;
        in
          conflicts == {};

        message = let
          # Group by port number
          byPort =
            groupBy (x: toString x.port)
            (mapAttrsToList (name: link: {
                inherit name;
                inherit (link) port;
              })
              config.links);

          # Filter to only the ports with multiple assignments
          conflicts = filterAttrs (_port: assignments: length assignments > 1) byPort;

          # Format each conflict as a string
          conflictStrings =
            mapAttrsToList (
              port: assignments: "Port ${port} is used by multiple links: ${
                concatStringsSep ", " (map (x: x.name) assignments)
              }"
            )
            conflicts;
        in ''
          Port Magic: Found port conflicts:
          ${concatStringsSep "\n" conflictStrings}
        '';
      }
    ];
  };
}
