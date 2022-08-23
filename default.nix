{ pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem }:

let
  inherit (pkgs) lib;
  releases = builtins.fromJSON (lib.strings.fileContents ./sources.json);
  mkDerivation = { url, version, sha256 }: pkgs.stdenv.mkDerivation {
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
in lib.attrsets.mapAttrs (k: v:
  if k == "master" then
    lib.attrsets.mapAttrs (k: v: (mkDerivation {
      inherit (v.${system}) version url sha256;
    })) v
  else
    mkDerivation {
      inherit (v.${system}) version url sha256;
    })
  releases
