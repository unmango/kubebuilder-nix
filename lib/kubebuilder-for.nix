# Build a specific kubebuilder release by overriding the nixpkgs package with
# the hashes recorded in versions.json.
{ kubebuilder, fetchFromGitHub }:
version:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pin =
    versions.${version}
      or (throw "kubebuilder-nix: no pin for kubebuilder ${version}; add it to lib/versions.json");
in
if kubebuilder.version == version then
  kubebuilder
else
  kubebuilder.overrideAttrs (_: {
    inherit version;
    src = fetchFromGitHub {
      owner = "kubernetes-sigs";
      repo = "kubebuilder";
      tag = "v${version}";
      inherit (pin) hash;
    };
    inherit (pin) vendorHash;
  })
