# Options for a kubebuilder project managed by kubebuilder-nix.
#
# The options are declared ahead of their implementation; they produce no
# outputs yet. See docs/design.md for what each will drive.
{ lib, flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption {
    options.kubebuilder = {
      enable = lib.mkEnableOption "kubebuilder-nix for this project";

      src = lib.mkOption {
        type = lib.types.path;
        description = "Project root containing PROJECT and hack/boilerplate.go.txt.";
      };

      version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Kubebuilder release to scaffold with. Defaults to the nixpkgs package.";
      };

      hash = lib.mkOption {
        type = lib.types.str;
        default = lib.fakeHash;
        description = "Output hash of the scaffold for the chosen version.";
      };
    };
  };
}
