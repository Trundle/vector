{
  description = "A lightweight, ultra-fast tool for building observability pipelines";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    let
      cargoTOML = builtins.fromTOML (builtins.readFile ./Cargo.toml);
      name = cargoTOML.package.name;

      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [
          rust-overlay.overlays.default

          (final: prev: {
            rustToolchain = final.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          })
        ];
      };

      lib = nixpkgs.lib;
      systems = flake-utils.lib.system;
    in
    lib.foldl lib.recursiveUpdate { } [
      (flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = pkgsFor system;
        in
        {
          devShells.default = pkgs.mkShell {
            name = "${name}-dev-shell";

            nativeBuildInputs = with pkgs; [
              rustToolchain
            ];

            buildInputs = with pkgs; [
              protobuf
            ];
          };
        }))
    ];
}
