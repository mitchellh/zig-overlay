{
  description = "Zig compiler binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    # Used for shell.nix
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (nixpkgs) lib;

    # flake-utils polyfill
    eachSystem = systems: fn:
      lib.foldl' (
        acc: system:
          lib.recursiveUpdate
          acc
          (lib.mapAttrs (_: value: {${system} = value;}) (fn system))
      ) {}
      systems;

    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = eachSystem systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in rec {
      # The packages exported by the Flake:
      #  - default - latest /released/ version
      #  - <version> - tagged version
      #  - master - latest nightly (updated daily)
      #  - master-<date> - nightly by date
      packages = import ./default.nix {inherit system pkgs;};

      # "Apps" so that `nix run` works. If you run `nix run .` then
      # this will use the latest default.
      apps = rec {
        default = apps.zig;
        zig = {
          type = "app";
          program = toString packages.default;
        };
      };

      # nix fmt
      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          curl
          jq
          minisign
        ];
      };

      # For compatibility with older versions of the `nix` binary
      devShell = self.devShells.${system}.default;
    });
  in
    outputs
    // {
      # Overlay that can be imported so you can access the packages
      # using zigpkgs.master or whatever you'd like.
      overlays.default = final: prev: {
        zigpkgs = outputs.packages.${prev.system};
      };

      # Templates for use with nix flake init
      templates.compiler-dev = {
        path = ./templates/compiler-dev;
        description = "A development environment for Zig compiler development.";
      };

      templates.init = {
        path = ./templates/init;
        description = "A basic, empty development environment.";
      };
    };
}
