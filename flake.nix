{
  description = "Zig compiler binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    # List of systems where binaries are provided.
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" ];
    in flake-utils.lib.eachSystem systems (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        packages = import ./default.nix { inherit system pkgs; };
        apps = rec {
          default = apps.zig;
          zig = flake-utils.lib.mkApp { drv = packages.default; };
        };
      });
}
