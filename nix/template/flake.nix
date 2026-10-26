{
  description = "A NixOS system with Niri and iNiR";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    inir = {
      url = "github:snowarch/inir";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, inir, ... }: {
    nixosConfigurations.inir = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inir.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
