# Nix Flake for Zig

This repository is a Nix flake packaging the [Zig](https://ziglang.org)
compiler. The flake mirrors the binaries built officially by Zig and
does not build them from source.

This repository is meant to be consumed primarily as a flake but the
`default.nix` can also be imported directly by non-flakes, too.

The flake outputs are documented in `flake.nix` but an overview:

  * Default package and "app" is the latest released version
  * `packages.<version>` for a tagged release
  * `packages.master` for the latest nightly release
  * `packages.master-<date>` for a nightly release
  * `overlays.default` is an overlay that adds `zigpkgs` to be the packages
    exposed by this flake
  * `templates.compiler-dev` to setup a development environment for Zig
    compiler development.

## Usage

### Flake

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
# open a shell with a specific zig version
$ nix shell 'github:mitchellh/zig-overlay#"0.14.0"'
```

### Compiler Development

This flake outputs a template that makes it easy to work on the Zig
compiler itself. If you're looking to contribute to the Zig compiler,
here are the easy steps to setup a working development environment:

```sh
# clone zig and go into that directory
$ git clone https://github.com/ziglang/zig.git
$ cd zig
# setup the template
$ nix flake init -t 'github:mitchellh/zig-overlay#compiler-dev'
# Two options:
# (1) start a shell, this forces bash
$ nix develop
# (2) If you have direnv installed, you can start the shell environment
# in your active shell (fish, zsh, etc.):
$ direnv allow
```

## FAQ

### Why is a Nightly Missing?

There are two possible reasons:

1. The Zig download JSON that is used to generate this overlay only shows
the latest _master_ release. It doesn't keep track of historical releases.
If this overlay wasn't running or didn't exist at the time of a release,
we could miss a day. This is why historical dates beyond a certain point
don't exist; they predate this overlay (or original overlays this derives
from).

2. The official Zig CI only generates a master release if the CI runs 
full green. During certain periods of development, a full day may go by
where the master branch of the Zig compiler is broken. In this scenario,
a master build (aka "nightly") is not built or released at all.

## Thanks

The `sources.json` file was originally from another Zig overlay repository
hosted by the username `arqv`. This user and repository was deleted at some
point, so I started a new flake based on the same `sources.json` format
they used so I could inherit the history. Thank you for compiling nightly
release information since 2021!
