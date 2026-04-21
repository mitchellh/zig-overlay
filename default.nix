{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {},
  system ? builtins.currentSystem,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);
  mirrors = builtins.fromJSON (lib.strings.fileContents ./mirrors.json);
  brewSources = builtins.fromJSON (lib.strings.fileContents ./brew-sources.json);

  # mkBinaryInstall makes a derivation that installs Zig from a binary.
  mkBinaryInstall = {
    url,
    version,
    sha256,
  }: let
    tarballName = lib.lists.last (lib.strings.split "/" url);
    srcIsFromZigLang = lib.strings.hasPrefix "https://ziglang.org/" url;
    urlFromMirrors =
      builtins.map
      (mirror: "${mirror}/${tarballName}?source=nix-zig-overlay")
      mirrors;
    urls =
      if srcIsFromZigLang
      then urlFromMirrors ++ [url]
      else [url];
  in
    pkgs.stdenv.mkDerivation (finalAttrs: {
      inherit version;

      pname = "zig";
      src = pkgs.fetchurl {inherit urls sha256;};
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        mkdir -p $out/{doc,bin,lib}
        [ -d docs ] && cp -r docs/* $out/doc
        [ -d doc ] && cp -r doc/* $out/doc
        cp -r lib/* $out/lib
        substituteInPlace $out/lib/std/zig/system.zig \
          --replace "/usr/bin/env" "${pkgs.lib.getExe' pkgs.coreutils "env"}"
        cp zig $out/bin/zig
      '';

      passthru = let
        mkPassthru = import "${nixpkgs}/pkgs/development/compilers/zig/passthru.nix";
      in
        mkPassthru ({
            inherit
              (pkgs)
              stdenv
              callPackage
              wrapCCWith
              wrapBintoolsWith
              overrideCC
              ;
            zig = finalAttrs.finalPackage;
          }
          // lib.optionalAttrs ((builtins.functionArgs mkPassthru) ? lib) {
            inherit lib;
          }
          // lib.optionalAttrs ((builtins.functionArgs mkPassthru) ? targetPackages) {
            inherit (pkgs) targetPackages;
          });

      meta =
        pkgs.zig.meta
        // {
          mainProgram = "zig";
          platforms = [system];
        };
    });

  # mkBrewInstall makes a self-contained derivation that installs Zig from
  # Homebrew bottles, bundling all dylib dependencies (LLVM, LLD, zstd).
  # All @@HOMEBREW_PREFIX@@ and @rpath references are resolved so that no
  # Homebrew installation is needed at runtime.
  mkBrewInstall = {
    version,
    formula,
    bottles,
  }: let
    # Fetch each bottle as a separate fixed-output derivation
    bottleSrcs =
      lib.attrsets.mapAttrs
      (name: b:
        pkgs.fetchurl {
          inherit (b) url sha256;
          curlOptsList = ["-H" "Authorization: Bearer QQ=="];
        })
      bottles;
  in
    pkgs.stdenv.mkDerivation (finalAttrs: {
      inherit version;

      pname = "zig";
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      dontUnpack = true;
      nativeBuildInputs = [pkgs.darwin.cctools pkgs.darwin.sigtool];

      installPhase = let
        # Unpack all bottles into $TMPDIR/bottles
        unpackCmds = lib.concatStringsSep "\n" (
          lib.attrsets.mapAttrsToList
          (name: src: "tar -xzf ${src} -C $TMPDIR/bottles")
          bottleSrcs
        );
        zigRoot = bottles.${formula}.root;
      in ''
        mkdir -p $TMPDIR/bottles
        ${unpackCmds}

        # Install zig
        mkdir -p $out/{bin,lib,lib/brew}
        cp $TMPDIR/bottles/${zigRoot}/bin/zig $out/bin/zig
        cp -r $TMPDIR/bottles/${zigRoot}/lib/* $out/lib
        substituteInPlace $out/lib/zig/std/zig/system.zig \
          --replace-fail "/usr/bin/env" "${pkgs.lib.getExe' pkgs.coreutils "env"}"

        # Collect all candidate dylibs from dependency bottles
        candidates=$TMPDIR/candidates
        mkdir -p $candidates
        find $TMPDIR/bottles -name '*.dylib' -exec cp -n {} $candidates/ \;

        # Recursively copy needed dylibs starting from the zig binary
        copy_needed() {
          local file="$1"
          otool -L "$file" | tail -n +2 | awk '{print $1}' | while read -r dep; do
            case "$dep" in
              /usr/lib/*|/System/Library/*) continue ;;
            esac
            local base
            base="$(basename "$dep")"
            local target="$out/lib/brew/$base"
            if [ ! -e "$target" ] && [ -e "$candidates/$base" ]; then
              cp -L "$candidates/$base" "$target"
              chmod u+w "$target"
              copy_needed "$target"
            fi
          done
        }
        copy_needed $out/bin/zig

        # Patch all Mach-O files: rewrite dylib refs to @rpath
        patch_file() {
          local file="$1"
          local is_zig_bin=0
          [ "$file" = "$out/bin/zig" ] && is_zig_bin=1

          # Set dylib ID for bundled libs
          if [ "$is_zig_bin" -eq 0 ]; then
            install_name_tool -id "@rpath/$(basename "$file")" "$file"
          fi

          # Rewrite all non-system deps to @rpath
          otool -L "$file" | tail -n +2 | awk '{print $1}' | while read -r dep; do
            case "$dep" in
              /usr/lib/*|/System/Library/*|@rpath/*) continue ;;
            esac
            install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$file"
          done

          # Add rpath
          if [ "$is_zig_bin" -eq 1 ]; then
            install_name_tool -add_rpath "@executable_path/../lib/brew" "$file" 2>/dev/null || true
          else
            install_name_tool -add_rpath "@loader_path" "$file" 2>/dev/null || true
          fi
        }

        # Patch zig binary and all bundled dylibs
        patch_file $out/bin/zig
        for dylib in $out/lib/brew/*.dylib; do
          [ -e "$dylib" ] && patch_file "$dylib"
        done

        # Re-sign all patched Mach-O files (required on macOS)
        codesign -f -s - $out/bin/zig
        for dylib in $out/lib/brew/*.dylib; do
          [ -e "$dylib" ] && codesign -f -s - "$dylib"
        done

        # Verify no Homebrew references remain
        if otool -L $out/bin/zig $out/lib/brew/*.dylib 2>/dev/null | grep -q '@@HOMEBREW_PREFIX@@\|/opt/homebrew\|/usr/local/opt'; then
          echo "ERROR: Homebrew references still present:" >&2
          otool -L $out/bin/zig $out/lib/brew/*.dylib | grep '@@HOMEBREW_PREFIX@@\|/opt/homebrew\|/usr/local/opt' >&2
          exit 1
        fi
      '';

      passthru = let
        mkPassthru = import "${nixpkgs}/pkgs/development/compilers/zig/passthru.nix";
      in
        mkPassthru ({
            inherit
              (pkgs)
              stdenv
              callPackage
              wrapCCWith
              wrapBintoolsWith
              overrideCC
              ;
            zig = finalAttrs.finalPackage;
          }
          // lib.optionalAttrs ((builtins.functionArgs mkPassthru) ? lib) {
            inherit lib;
          }
          // lib.optionalAttrs ((builtins.functionArgs mkPassthru) ? targetPackages) {
            inherit (pkgs) targetPackages;
          });

      meta =
        pkgs.zig.meta
        // {
          mainProgram = "zig";
          platforms = [system];
        };
    });

  # The packages that are tagged releases
  taggedPackages =
    lib.attrsets.mapAttrs
    (k: v:
      mkBinaryInstall {
        inherit (v.${system}) version url sha256;
      })
    (lib.attrsets.filterAttrs
      (k: v: (builtins.hasAttr system v) && (v.${system}.url != null) && (v.${system}.sha256 != null))
      (builtins.removeAttrs sources ["master"]));

  # The master packages
  masterPackages =
    lib.attrsets.mapAttrs' (
      k: v:
        lib.attrsets.nameValuePair
        (
          if k == "latest"
          then "master"
          else ("master-" + k)
        )
        (mkBinaryInstall {
          inherit (v.${system}) version url sha256;
        })
    )
    (lib.attrsets.filterAttrs
      (k: v: (builtins.hasAttr system v) && (v.${system}.url != null) && (v.${system}.sha256 != null))
      sources.master);

  # The packages from Homebrew bottles (macOS-patched builds)
  brewPackages =
    lib.attrsets.mapAttrs
    (k: v:
      mkBrewInstall {
        inherit (v.${system}) version formula bottles;
      })
    (lib.attrsets.filterAttrs
      (k: v: (builtins.hasAttr system v) && (v.${system} ? bottles))
      brewSources);

  # This determines the latest /released/ version.
  latest = lib.lists.last (
    builtins.sort
    (x: y: (builtins.compareVersions x y) < 0)
    (builtins.attrNames taggedPackages)
  );
in
  # We want the packages but also add a "default" that just points to the
  # latest released version.
  taggedPackages // masterPackages // {"default" = taggedPackages.${latest};} // lib.optionalAttrs (brewPackages != {}) {brew = brewPackages;}
