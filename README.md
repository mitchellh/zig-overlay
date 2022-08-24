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
  * `template.compiler-dev` to setup a development environment for Zig
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

## Thanks

The `sources.json` file was originally from another Zig overlay repository
hosted by the username `arqv`. This user and repository was deleted at some
point, so I started a new flake based on the same `sources.json` format
they used so I could inherit the history. Thank you for compiling nightly
release information since 2021!
