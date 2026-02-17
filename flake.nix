{
  description = "Zig compiler binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    systems = {
      url = "github:nix-systems/default";
      flake = false;
    };

    # Used for shell.nix
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    ...
  }: let
    inherit (nixpkgs) lib;

    eachSystem = lib.genAttrs (import systems);

    pkgsFor = eachSystem (system: nixpkgs.legacyPackages.${system});
  in {
    # The packages exported by the Flake:
    #  - default - latest /released/ version
    #  - <version> - tagged version
    #  - master - latest nightly (updated daily)
    #  - master-<date> - nightly by date
    packages = lib.mapAttrs (system: pkgs: import ./default.nix {inherit nixpkgs system pkgs;}) pkgsFor;

    # Overlay that can be imported so you can access the packages
    # using zigpkgs.master or whatever you'd like.
    overlays.default = final: prev: {
      zigpkgs = self.packages.${prev.system};
    };

    # "Apps" so that `nix run` works. If you run `nix run .` then
    # this will use the latest default.
    apps = eachSystem (system: {
      default = self.apps.${system}.zig;
      zig = {
        type = "app";
        program = self.packages.${system}.default.outPath;
      };
    });

    # nix fmt
    formatter = lib.mapAttrs (_: pkgs: pkgs.alejandra) pkgsFor;

    devShells =
      lib.mapAttrs (system: pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            curl
            jq
            minisign
          ];
        };
      })
      pkgsFor;

    # For compatibility with older versions of the `nix` binary
    devShell = eachSystem (system: self.devShells.${system}.default);

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
