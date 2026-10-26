# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Overview

Nix builders for Kubebuilder project scaffolds.
A scaffold is what `kubebuilder alpha generate` produces from a `PROJECT` file, built here as a fixed-output derivation per Kubebuilder version.
`docs/research.md` records how Kubebuilder's regeneration and upgrade commands work, and `docs/design.md` describes where this repo is going.

## Commands

```bash
nix develop          # Dev shell: kubebuilder, go, git, gnumake, nixfmt
nix fmt              # Format with treefmt (nixfmt, prettier, actionlint)
nix flake check      # Build the example scaffolds and check formatting
nix build .#         # Link farm of the example scaffolds
make check           # Same as nix flake check
make update          # nix flake update
```

## Architecture

- `lib/` - the library exposed as `flake.lib` by `lib/default.nix`.
  Every function it exposes takes `pkgs` first.
  The files below it are `callPackage` style, taking their dependencies as arguments.
  - `mk-scaffold.nix` - `mkScaffold pkgs { src, hash, version ? null, name ? }`. `src` holds `PROJECT` and `hack/boilerplate.go.txt`.
  - `kubebuilder-for.nix` - `kubebuilderFor pkgs version`, which overrides `pkgs.kubebuilder` with a pin from `versions.json`.
  - `versions.json` - source `hash` and `vendorHash` per Kubebuilder release.
- `modules/flake-module.nix` - the flake-parts module exposed as `flakeModules.default`. It only declares options so far.
- `checks/` - one scaffold check per pinned Kubebuilder version, built from `examples/`.
- `examples/memcached/` - a `PROJECT` with one API and the `helm/v2-alpha` plugin.
- `docs/` - research notes and the design.

### Why scaffolds are fixed-output derivations

`kubebuilder init` runs `go mod tidy`, and the post-scaffold `make` targets `go install` controller-gen, kustomize, and golangci-lint at the versions the generated Makefile pins.
All of that needs the network, so the scaffold declares its output hash, the same way `vendorHash` works for `buildGoModule`.
Pointing the Makefile at nixpkgs tools does not work: its `go-install-tool` recipe runs `rm` on the tool path when the file looks stale, and store paths are read-only with a 1970 mtime.

The build sets `SHELL` and `LOCALBIN` through `MAKEFLAGS`, because the generated Makefile uses `/usr/bin/env bash`, which the sandbox lacks, and puts tools in `./bin`, which would end up in the output.

### Adding a Kubebuilder version

1. Add the release to `lib/versions.json` with empty hashes, then build `kubebuilderFor pkgs "<version>"` to learn the real ones.
2. Add a check in `checks/default.nix` with `pkgs.lib.fakeHash`, build it, and copy the reported hash.
3. Confirm the scaffold is reproducible with `nix build .#checks.x86_64-linux.<name> --rebuild`.

## Agent skills

### Issue tracker

Issues are tracked in this repo's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage labels, each named after its role (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
