# sentry-cli-nix

A standalone Nix flake for the **new [`sentry` CLI](https://cli.sentry.dev)**
from [`getsentry/toolkit`](https://github.com/getsentry/toolkit/tree/main/packages/cli).
This is the TypeScript CLI for interacting with Sentry, distinct from the older
Rust `sentry-cli` already packaged in nixpkgs. The overlay adds `pkgs.sentry`;
it can coexist with `pkgs.sentry-cli`.

## Run or install

```sh
nix run github:joninvski/sentry-cli-nix -- --help
nix profile install github:joninvski/sentry-cli-nix#sentry
```

Outputs include `packages.<system>.sentry` (also `default`),
`apps.<system>.default`, `formatter.<system>`, `checks.<system>`, and
`overlays.default`. Supported systems: `x86_64-linux`, `aarch64-linux`,
`aarch64-darwin`, and `x86_64-darwin`.

The lock file selects a nixos-unstable revision that still supports Intel
macOS. Newer unstable revisions have removed the Intel macOS bootstrap tools;
keep that in mind when updating the lock or using `nixpkgs.follows` on that
platform. The overlay works with your chosen nixpkgs, which must support your
system and provide Node 22.15 or newer.

## Use in another flake

Add these inputs:

```nix
inputs.sentry-cli-nix.url = "github:joninvski/sentry-cli-nix";
inputs.sentry-cli-nix.inputs.nixpkgs.follows = "nixpkgs";
```

Include `sentry-cli-nix` (or `inputs@{ ... }`) in your `outputs` arguments.
In a NixOS or standalone Home Manager module where `inputs` is available:

```nix
{ inputs, pkgs, lib, ... }: {
  nixpkgs.overlays = [ inputs.sentry-cli-nix.overlays.default ];
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "sentry";

  # NixOS:
  environment.systemPackages = [ pkgs.sentry ];
  # For standalone Home Manager, use instead:
  # home.packages = [ pkgs.sentry ];
}
```

Pass `specialArgs = { inherit inputs; };` to `nixpkgs.lib.nixosSystem`, or
`extraSpecialArgs = { inherit inputs; };` to `home-manager.lib.homeManagerConfiguration`.
With Home Manager's `useGlobalPkgs = true`, configure the overlay and license
policy in NixOS and use `home.packages = [ pkgs.sentry ];` in Home Manager.
If you already have an `allowUnfreePredicate`, extend it to include `sentry`.

For a direct package reference without the overlay:

```nix
home.packages = [ inputs.sentry-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.sentry ];
```

## License

Upstream uses **FSL-1.1-Apache-2.0** (Functional Source License with an Apache
2.0 future license), not Apache-2.0 alone. The package marks it `free = false`
and redistributable. Review the [upstream license](https://github.com/getsentry/toolkit/blob/main/LICENSE.md).
The flake's direct package/app/check outputs explicitly permit only `sentry`,
so `nix run`, `nix build`, and `nix flake check` work without impure environment
configuration. Overlay consumers must allow it in their own nixpkgs instance
using `allowUnfreePredicate` as above.

## Runtime and setup

The npm archive has no runtime npm dependencies. It ships bundled JavaScript,
WASM drivers, and other assets; all are retained in `$out/lib/sentry`.
The wrapper uses nixpkgs `nodejs_22` (22.15 or newer for built-in `node:sqlite`).
There is no npm install, monorepo build, or install-time download.

The CLI writes credentials and state to `~/.config/sentry/` (or under
`$XDG_CONFIG_HOME/sentry/` when configured). Keep this directory private.
Package-manager installs skip upstream's automatic setup; run this yourself
to install agent skills and shell completions:

```sh
sentry cli setup
```

## Development and updates

```sh
nix flake check
nix build .#sentry
./result/bin/sentry --version
./result/bin/sentry --help
nix fmt
./update.sh
```

`update.sh` requires Nix, Python 3, Bash, and `realpath`. It queries npm's latest
stable release, checks that the license/entry point/dependency contract is
unchanged, prefetches the archive, and updates `package.nix` with its version
and SHA-256 hash. It leaves the nixpkgs lock unchanged; update that separately
with `nix flake update nixpkgs`.

CI checks, builds, and smoke-tests Linux and macOS on Intel and ARM runners.
A daily workflow opens an update PR after checking the new package on Linux.
For a fork, enable **Settings → Actions → General → Allow GitHub Actions to
create and approve pull requests**. The built-in `GITHUB_TOKEN` is sufficient;
no personal token is needed. PRs made with that token do not automatically
trigger other workflows; use CI's manual dispatch on the update branch when
you want the full platform matrix before merging.
