{ pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem }:

let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);

  # mkBinaryInstall makes a derivation that installs Zig from a binary.
  mkBinaryInstall = { url, version, sha256 }: pkgs.stdenv.mkDerivation {
    inherit version;

    pname = "zig";
    src = pkgs.fetchurl { inherit url sha256; };
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      mkdir -p $out/{doc,bin,lib}
      [ -d docs ] && cp -r docs/* $out/doc
      [ -d doc ] && cp -r doc/* $out/doc
      cp -r lib/* $out/lib
      cp zig $out/bin/zig
    '';
  };

  # This determines the latest /released/ version.
  latest = lib.lists.last (
    builtins.sort
      (x: y: (builtins.compareVersions x y) < 0)
      (builtins.filter (x: x != "master") (builtins.attrNames sources))
  );

  # This is the full list of packages
  packages = lib.attrsets.mapAttrs (k: v:
    if k == "master" then
      lib.attrsets.mapAttrs (k: v: (mkBinaryInstall {
        inherit (v.${system}) version url sha256;
      })) v
    else
      mkBinaryInstall {
        inherit (v.${system}) version url sha256;
      })
      sources;
in
  # We want the packages but also add a "default" that just points to the
  # latest released version.
  packages // { "default" = packages.${latest}; }
