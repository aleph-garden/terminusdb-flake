{
  description = "TerminusDB server and tools packaged for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: {
        packages = {
          terminusdb = pkgs.callPackage ./packages/terminusdb {};
          default = self'.packages.terminusdb;
        };

        checks = {
          nixos-test = import ./tests/nixos-test.nix {
            inherit pkgs;
            terminusdb = inputs.self;
          };
        };

        formatter = pkgs.alejandra;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nil # Nix LSP
            nixpkgs-fmt
            self'.packages.terminusdb
          ];

          shellHook = ''
            echo "TerminusDB development environment"
            echo "Available: terminusdb"
          '';
        };
      };

      flake = {
        nixosModules.default = import ./modules/nixos;
        nixosModules.terminusdb = import ./modules/nixos;
        homeManagerModules.default = import ./modules/home-manager;
        homeManagerModules.terminusdb = import ./modules/home-manager;
      };
    };
}
