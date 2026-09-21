# Design

A Kubebuilder scaffold depends only on the Kubebuilder release, `PROJECT`, and `hack/boilerplate.go.txt`.
That makes it a derivation.
Everything `kubebuilder alpha update` does before its final merge can then come from the Nix store, with binaries pinned by the flake instead of downloaded at runtime.

## Scaffold

`lib.mkScaffold pkgs { src, hash, version ? null }` runs `kubebuilder alpha generate --output-dir $out` over `src`.

It is a fixed-output derivation, because the replay needs the network for Go modules and for the tools the generated Makefile installs.
See `AGENTS.md` for why the Makefile's tools cannot come from nixpkgs.

### Spike result

The `examples/memcached` scaffold builds for Kubebuilder 4.15.0 and 4.16.0.
`nix build --rebuild` reproduces both outputs bit for bit, and the outputs contain no store references.
`go.mod` and `go.sum` are stable because `go get` pins controller-runtime and Go's minimal version selection resolves the rest.

The hash depends on the Go toolchain as well as Kubebuilder, because `go mod init` writes the toolchain version into `go.mod`.
A nixpkgs bump that changes `go` changes every scaffold hash.

## Versions

`lib/versions.json` pins each Kubebuilder release by source `hash` and `vendorHash`, and `lib.kubebuilderFor pkgs version` builds it by overriding `pkgs.kubebuilder`.
That table replaces the release download that `alpha update` does.

## Layers

`alpha generate` replays `PROJECT` in a fixed order: init, resources, grafana, autoupdate, helm, deploy-image.
Building a scaffold from a `PROJECT` reduced to a prefix of that order gives one derivation per layer:

1. `base`: `PROJECT` with `resources` and `plugins` removed.
2. `resources`: plus `resources`.
3. One layer per configured plugin, in replay order.

The diff between consecutive layers is exactly what that plugin writes.
This makes plugin ownership visible, and lets a project drop or replace a layer, for example a Helm chart it manages itself.

## Project layer

The `kubernetes-operator` template in `UnstoppableMango/nix` keeps its own `Makefile`, `.gitignore`, `.golangci.yml`, and `.editorconfig` by moving them aside during `kubebuilder init`.
It then deletes `Dockerfile`, `.dockerignore`, `.devcontainer`, and Kubebuilder's CI workflows.

Here that becomes a final layer over the scaffold: a set of overrides and deletions applied by Nix.
The template can then import this repo's flake module in place of `hack/init.sh`.

## Update

`apps.kubebuilder-update` does the impure part of `alpha update`:

1. Build the ancestor scaffold at `cliVersion` from `PROJECT` and the upgrade scaffold at the target release. Both are store paths.
2. Commit each to a temporary branch in the working repository, the ancestor first and the upgrade on top of it.
3. Merge the user's branch into the upgrade branch with git, and run `make manifests generate fmt vet lint-fix`.
4. Leave the result on an output branch named like upstream's, `kubebuilder-update-from-<from>-to-<to>`.

Because the scaffolds are cached, only the merge runs on each invocation.

## Flake module

`flakeModules.default` declares `perSystem.kubebuilder.{enable, src, version, hash}`.
It will produce:

- `packages.kubebuilder-scaffold`: the scaffold at `version`.
- `apps.kubebuilder-update`: the update app, targeting `version`.
- `checks.kubebuilder-scaffold`: the scaffold builds, which catches a stale `hash`.
- A dev shell with the Kubebuilder release matching `cliVersion`.

## Upgrade flow

Renovate bumps `kubebuilder.version` in the project's flake.
CI runs the update app and pushes the output branch.
This replaces the upstream autoupdate plugin's GitHub Action and its runtime binary download.

## Open questions

- Whether the scaffold `hash` can be avoided by vendoring Go modules through a separate fixed-output step, leaving the scaffold itself a normal derivation.
- Whether layers should be real derivations or computed on demand for inspection only.
- How `--restore-path` maps onto the project layer.
