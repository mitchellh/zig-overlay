{
  description = "Zig compiler binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    # List of systems where binaries are provided.
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in flake-utils.lib.eachSystem systems (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        packages = import ./default.nix { inherit system pkgs; };
        defaultPackage = packages."0.7.1";
        apps.zig = flake-utils.lib.mkApp { drv = defaultPackage; };
        defaultApp = apps.zig;
      });
}
