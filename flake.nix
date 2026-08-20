{
  description = "iNiR desktop shell for Niri, packaged for NixOS and Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      nixosModule = import ./nix/nixos-module.nix;
      homeModule = import ./nix/home-module.nix;
    in
    {
      packages = forAllSystems (pkgs:
        let
          package = pkgs.callPackage ./nix/package.nix { inherit pkgs; };
        in
        {
          default = package;
          inir = package;
        });

      nixosModules.default = nixosModule;
      nixosModules.inir = nixosModule;

      homeModules.default = homeModule;
      homeModules.inir = homeModule;

      # Conventional alias most Home Manager setups look for.
      homeManagerModules.default = homeModule;
      homeManagerModules.inir = homeModule;

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
