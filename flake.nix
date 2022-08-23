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
        # The packages exported by the Flake:
        #  - default - latest /released/ version
        #  - <version> - tagged version
        #  - master - latest nightly (updated daily)
        #  - master-<date> - nightly by date
        packages = import ./default.nix { inherit system pkgs; };

        # "Apps" so that `nix run` works. If you run `nix run .` then
        # this will use the latest default.
        apps = rec {
          default = apps.zig;
          zig = flake-utils.lib.mkApp { drv = packages.default; };
        };

        # Overlay that can be imported so you can access the packages
        # using zigpkgs.master.latest or whatever you'd like.
        overlay = final: prev: {
          zigpkgs = packages.${prev.system};
        };
      });
}
