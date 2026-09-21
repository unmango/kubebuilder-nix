# Research: how Kubebuilder regenerates and upgrades projects

Findings as of Kubebuilder v4.16.0 (released 2026-09-10).

## The PROJECT file

`PROJECT` is the source of truth for scaffolding ([reference](https://book.kubebuilder.io/reference/project-config)).
It holds `version: "3"`, `cliVersion`, `layout` (the plugin chain, for example `go.kubebuilder.io/v4`), `domain`, `repo`, `projectName`, `multigroup`, a `resources` list, and a `plugins` map.
Each resource records its group, version, kind, and whether it has an API, a controller, and webhooks.
Optional plugins keep their configuration under their key in `plugins`, for example `helm.kubebuilder.io/v2-alpha: {manifests, output}` or `deploy-image.go.kubebuilder.io/v1-alpha: {resources: [...]}`.

`PROJECT` stores the end state.
It does not record the commands that were run or their order.

Plugin keys in current use: `go.kubebuilder.io/v4` (a bundle of `base.go` and `kustomize.common/v2`), `deploy-image.go.kubebuilder.io/v1-alpha`, `grafana.kubebuilder.io/v1-alpha`, `helm.kubebuilder.io/v2-alpha`, and `autoupdate.kubebuilder.io/v1-alpha`.
`helm/v1-alpha` is deprecated in source.

## `kubebuilder alpha generate`

Rebuilds a project from `PROJECT` ([reference](https://book.kubebuilder.io/reference/commands/alpha_generate)).

Flags: `--input-dir` (defaults to the working directory), `--output-dir`, and `--plugins`.
Without `--output-dir` it regenerates in place, deleting everything except `.git` after reading `PROJECT` and `hack/boilerplate.go.txt`.

`Generate()` in `internal/cli/alpha/internal/generate.go` replays the project in a fixed order:

1. `init --plugins <layout chain>`, with outdated plugin keys replaced by current ones.
2. `create api` for each resource, then `create webhook` for each webhook.
3. `edit --plugins grafana/v1-alpha` when that plugin is configured.
4. `edit --plugins autoupdate/v1-alpha` when that plugin is configured.
5. `edit --plugins helm/v2-alpha` with the stored configuration.
6. `create api --plugins deploy-image/v1-alpha` for each resource that plugin stores.

Each step is one CLI invocation derived from one section of `PROJECT`.
Those invocations are the layers: the order comes from Kubebuilder's code, not from the project's history.

The `go/v4` steps run post-scaffold tasks: `go mod tidy`, `make generate`, `make manifests`, and `make lint-fix`.
The generated Makefile `go install`s controller-gen, kustomize, setup-envtest, and golangci-lint into `./bin` at pinned versions, so a scaffold needs the network.

## `kubebuilder alpha update`

Upgrades a project to a newer Kubebuilder release ([reference](https://book.kubebuilder.io/reference/commands/alpha_update), source in `internal/cli/alpha/internal/update/update.go`).
It supports projects created with v4.5.0 or later, and `cliVersion` is present in `PROJECT` from v4.6.0 on.

It works in four temporary branches:

- `tmp-ancestor-<suffix>`: `--from-branch`, emptied except for `.git` and `PROJECT`, then regenerated with the old release.
- `tmp-original-<suffix>`: a snapshot of the user's code.
- `tmp-upgrade-<suffix>`: branched from the ancestor, emptied, then regenerated with the new release.
- `tmp-merge-<suffix>`: `original` merged into `upgrade` with a normal git three-way merge, followed by `make manifests generate fmt vet lint-fix`.

The result is squashed onto the output branch by default.
The binaries for both releases are downloaded at runtime from `https://github.com/kubernetes-sigs/kubebuilder/releases/download/<version>/kubebuilder_<os>_<arch>` (`helpers/download.go`).

Flags:

| Flag                 | Meaning                                                                               |
| -------------------- | ------------------------------------------------------------------------------------- |
| `--from-version`     | Release the project was scaffolded with. Defaults to `cliVersion`.                    |
| `--to-version`       | Target release. Defaults to the latest.                                               |
| `--from-branch`      | Base branch. Defaults to `main`.                                                      |
| `--force`            | Commit files that still have conflict markers.                                        |
| `--show-commits`     | Keep the full history instead of squashing.                                           |
| `--restore-path`     | Repeatable. Keep these paths from the base branch. Not allowed with `--show-commits`. |
| `--output-branch`    | Defaults to `kubebuilder-update-from-<from>-to-<to>`.                                 |
| `--push`             | Push the output branch.                                                               |
| `--open-gh-issue`    | Open a GitHub issue with a compare link. Needs `gh`.                                  |
| `--merge-message`    | Commit message for a clean merge.                                                     |
| `--conflict-message` | Commit message when conflicts remain.                                                 |
| `--git-config`       | Repeatable. Defaults raise `merge.renameLimit` and `diff.renameLimit`.                |

There is no `--squash` flag, since squashing is the default.
`--use-gh-models` was removed in v4.16.0.

## The autoupdate plugin

`kubebuilder edit --plugins=autoupdate/v1-alpha` writes `.github/workflows/auto_update.yml` ([reference](https://book.kubebuilder.io/plugins/available/autoupdate-v1-alpha)).
The workflow checks weekly for a new release and runs `kubebuilder alpha update --force --push --restore-path .github/workflows --open-gh-issue`.

## Nix

nixpkgs packages Kubebuilder as `kubebuilder` (`pkgs/by-name/ku/kubebuilder/package.nix`), at 4.15.0.
The package patches `internal/cli/version/version.go` so `kubebuilder version` reports the release.
Overriding `src` and `vendorHash` builds other releases, which `lib/kubebuilder-for.nix` does.

No existing project builds Kubebuilder scaffolds as derivations.
Related work:

- A Kubernetes operator flake template in `UnstoppableMango/nix` (`templates/kubernetes-operator`), whose `hack/init.sh` runs `kubebuilder init` while keeping the template's own files.
- Build-time code generation through dynamic derivations or IFD ([example](https://fzakaria.com/2025/03/11/nix-dynamic-derivations-a-practical-application)).
