# Wayseer for Nix

A Nix flake for [Wayseer Desktop](https://wayseer.app) on x86-64 Linux. It installs the
release served at `https://wayseer.app/v1/app/`, the same signed tarball every other Linux
user downloads, byte for byte.

```sh
nix run github:wayseer-net/desktop-nix
nix run github:wayseer-net/desktop-nix -- --demo    # Wayseer's flags go after --
```

`nix run` keeps any flag before `--` for itself.

## NixOS

Add the flake as an input, then turn on its module:

```nix
{
  inputs.wayseer.url = "github:wayseer-net/desktop-nix";

  outputs = { nixpkgs, wayseer, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      modules = [
        wayseer.nixosModules.default
        { programs.wayseer.enable = true; }
        ./configuration.nix
      ];
    };
  };
}
```

`programs.wayseer.enable` installs Wayseer for every user and turns on `hardware.graphics`,
which provides the GPU drivers. `programs.wayseer.package` picks another package.

To use your own nixpkgs instead, apply `overlays.default`, which adds `pkgs.wayseer`. Wayseer
is not free software, so that nixpkgs must allow it:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "wayseer";
```

The flake's own package and the module's default need nothing more.

## Updating

Wayseer installed this way never updates itself, and its update notices say to update through
Nix. When a release is out:

```sh
nix flake update wayseer     # in your flake, then rebuild
```

## What the package does

The package keeps the release's tarball unchanged in `libexec/wayseer`, and adds two things:

- `share/wayseer/installed-by`, saying `Nix`;
- `bin/wayseer`, a wrapper that starts the app through nixpkgs' glibc loader. The loader is
  told where nixpkgs' Wayland, xkbcommon, X11 and Vulkan libraries are, and the GPU drivers
  in `/run/opengl-driver/lib`.

Nothing in the tarball is patched, so the program that runs is the one Wayseer signed.

On a Linux other than NixOS, nixpkgs' Vulkan loader can't use the system's own GPU drivers.
Use [another of Wayseer's packages](https://wayseer.app/install#get) there.

## Releases

The package runs Wayseer 0.27.2 and later; it refuses an older tarball, whose app is laid out
differently. `scripts/bump.sh <version>` points `release.nix` at a served release. It reads the Linux
tarball's name, size and SHA-256 from the release file, then downloads the tarball and checks
it against them. It holds no key. It does not check the release's signature, so it is run only
on a release Wayseer has just published.

## Working on the flake

```sh
scripts/check.sh    # lint and test the scripts, build and test the package, scan for keys
```

`nix flake check` builds the package from an invented tarball and runs it, and needs no
network. The scripts' tests live in `tests/`, outside the Nix files, so they can be run and
linted directly:

```sh
bash tests/bump_test.sh
```

## License

The flake is MIT ([LICENSE](LICENSE)). Wayseer itself is under the
[Wayseer end-user license](https://wayseer.app/license).
