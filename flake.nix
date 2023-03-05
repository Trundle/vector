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
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane, ... }:
    let
      cargoTOML = builtins.fromTOML (builtins.readFile ./Cargo.toml);
      name = cargoTOML.package.name;

      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [
          rust-overlay.overlays.default

          (final: prev: {
            rustToolchain = final.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
            craneLib = (crane.mkLib prev).overrideToolchain final.rustToolchain;
          })
        ];
      };

      lib = nixpkgs.lib;
    in
    lib.foldl lib.recursiveUpdate { } [
      (flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = pkgsFor system;
        in
        {
          packages.default = pkgs.craneLib.buildPackage {
            pname = "vector";
            src = self;

            buildInputs = with pkgs; [
              openssl
            ];
            nativeBuildInputs = with pkgs; [
              git
              perl
              pkg-config
              rustPlatform.bindgenHook
            ];

            cargoExtraArgs = "-F api,api-client,sinks-azure_monitor_logs_dce,sinks-console,sources-file,sources-journald,transforms-remap --no-default-features";
            doCheck = false;

            PROTOC = "${pkgs.protobuf}/bin/protoc";
            PROTOC_INCLUDE = "${pkgs.protobuf}/include";
          };

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

      {
        overlays.default = final: _prev: {
          vector = self.packages.${final.system}.default;
        };
      }
    ];
}
