{
  description = "Zig compiler binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";

    # Used for shell.nix
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
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
        zig = flake-utils.lib.mkApp {drv = packages.default;};
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
