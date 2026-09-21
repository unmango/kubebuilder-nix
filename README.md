# kubebuilder-nix

Nix builders for [Kubebuilder](https://book.kubebuilder.io) project scaffolds.

Kubebuilder records a project's scaffolding in its `PROJECT` file, and `kubebuilder alpha generate` can rebuild the project from that file alone.
This repo builds that output as a derivation, pinned to a Kubebuilder release.
Two scaffolds of the same `PROJECT` at different releases are the inputs to the three-way merge that `kubebuilder alpha update` performs.

## Usage

```nix
kubebuilder-nix.lib.mkScaffold pkgs {
  src = ./.; # contains PROJECT and hack/boilerplate.go.txt
  version = "4.16.0";
  hash = "sha256-...";
}
```

The output is the full project tree as Kubebuilder would generate it, without `bin/`.

## Status

The scaffold builder works and is reproducible for Kubebuilder 4.15.0 and 4.16.0.
The flake-parts module and the upgrade app are designed in [docs/design.md](docs/design.md) but not yet written.
