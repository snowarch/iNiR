{
  description = "iNiR desktop shell for Niri, packaged for NixOS and Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      defaultOutputs = import ./.;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems f;
    in
    {
      packages = forAllSystems (system: {
        inir = defaultOutputs.package { pkgs = import nixpkgs { inherit system; }; };
        default = self.packages.${system}.inir;
      });

      nixosModules = {
        inir = defaultOutputs.nixosModule;
        default = self.nixosModules.inir;
      };

      homeModules = {
        inir = defaultOutputs.homeManagerModule;
        default = self.homeModules.inir;
      };

      # Conventional alias most Home Manager setups look for.
      homeManagerModules = {
        inir = defaultOutputs.homeManagerModule;
        default = self.homeManagerModules.inir;
      };

      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.nixpkgs-fmt
      );
    };
}
