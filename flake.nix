{
  description = "Nix builders for Kubebuilder scaffolds and upgrades";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:UnstoppableMango/nix-systems";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = with inputs; [
        systems.flakeModule
        treefmt-nix.flakeModule
        ./modules/flake-module.nix
      ];

      flake = {
        lib = import ./lib;
        flakeModules.default = ./modules/flake-module.nix;
      };

      perSystem =
        { config, pkgs, ... }:
        let
          kblib = import ./lib;
        in
        {
          checks = import ./checks { inherit pkgs kblib; };

          packages = {
            default = pkgs.linkFarm "kubebuilder-nix-examples" {
              inherit (config.checks) example-scaffold-4_15 example-scaffold-4_16;
            };
            kubebuilder_4_16 = kblib.kubebuilderFor pkgs "4.16.0";
          };

          devShells.default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              git
              gnumake
              go
              kubebuilder
              nixfmt
            ];
          };

          treefmt.programs = {
            actionlint.enable = true;
            nixfmt.enable = true;
            prettier.enable = true;
          };
        };
    };
}
