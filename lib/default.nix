let
  kubebuilderFor = pkgs: pkgs.callPackage ./kubebuilder-for.nix { };
in
{
  inherit kubebuilderFor;

  # `version` selects a kubebuilder release pinned in versions.json. Without it
  # the scaffold uses `pkgs.kubebuilder`.
  mkScaffold =
    pkgs:
    {
      version ? null,
      ...
    }@args:
    pkgs.callPackage ./mk-scaffold.nix {
      kubebuilder = if version == null then pkgs.kubebuilder else kubebuilderFor pkgs version;
    } (removeAttrs args [ "version" ]);
}
