# Nix Flake for Zig

This repository is a Nix flake packaging the [Zig](https://ziglang.com)
compiler. The flake mirrors the binaries built officially by Zig and
does not build them from source.

This repository is meant to be consumed primarily as a flake but the
`default.nix` can also be imported directly by non-flakes, too.

The flake outputs are documented in `flake.nix` but an overview:

  * Default package and "app" is the latest released version
  * `packages.<version>` for a tagged release
  * `packages.master` for the latest nightly release
  * `packages.master-<date>` for a nightly release
  * `overlay` is an overlay that adds `zigpkgs` to be the packages
    exposed by this flake

## Usage

### Flake Support

In your `flake.nix` file:

```nix
{
  inputs.zig.url = "github:mitchellh/zig-overlay";

  outputs = { self, zig, ... }: {
    ...
  };
}
```

In a shell:

```sh
# run the latest released version
$ nix run 'github:mitchellh/zig-overlay'
# open a shell with nightly version dated 2021-02-13 (oldest version available)
$ nix shell 'github:mitchellh/zig-overlay#master-2021-02-13'
# open a shell with latest nightly version
$ nix shell 'github:mitchellh/zig-overlay#master'
```

## Thanks

This repository is originally hosted by the username `arqv`. This user
and repository disappeared at some point and I had a local checkout so
I've forked it, modified it, and reuploaded it here.
