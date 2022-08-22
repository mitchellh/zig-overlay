# Nix Flake for Zig

This repository is a Nix flake packaging the [Zig](https://ziglang.com)
compiler. The flake mirrors the binaries built officially by Zig and
does not build them from source.

Provided packages:

  * Nightly versions updated daily (`.master.<date>`), starting from version
    `0.8.0-dev.1140+9270aae07` dated 2021-02-13, and latest master
	(`.master.latest`) for the sake of convenience.
  * Release versions.

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
# run the latest version (0.7.1)
$ nix run 'github:mitchellh/zig-overlay'
# open a shell with master version dated 2021-02-13 (oldest version available)
$ nix shell 'github:mitchellh/zig-overlay#master."2021-02-13"'
# open a shell with latest master version
$ nix shell 'github:mitchellh/zig-overlay#master.latest'
```

### No Flake Support

Import in your project as you would normally (`pkgs.fetchFromGitHub` or
`builtins.fetchgit`). The `default.nix` exposes a `pkgs` argument for possible
pinning of the nixpkgs repository, and a `system` argument which defaults to
`builtins.currentSystem`.

```nix
# It is a good idea to use an exact commit in place of 'main' here.
let zigf = fetchTarball "https://github.com/mitchellh/zig-overlay/archive/main.tar.gz" in
# If you're using home-manager
home.packages = [ zigf.master.latest ]; # or any available version
# If you're using NixOS
users.user.<username>.packages = [ zigf.master.latest ]; # or any available version
# ...the rest of your configuration
```

## Thanks

This repository is originally hosted by the username `arqv`. This user
and repository disappeared at some point and I had a local checkout so
I've forked it, modified it, and reuploaded it here.
