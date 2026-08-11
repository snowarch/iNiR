{
  package =
    {
      pkgs ? import <nixpkgs> { },
    }:
    pkgs.callPackage ./distro/nixos/package.nix { };

  nixosModule = { pkgs, lib, ... }: {
    imports = [ ./distro/nixos/nixos-module.nix ];
    programs.inir.package = lib.mkDefault (pkgs.callPackage ./distro/nixos/package.nix { });
  };

  homeManagerModule = { pkgs, lib, ... }: {
    imports = [ ./distro/nixos/home-manager-module.nix ];
    programs.inir.package = lib.mkDefault (pkgs.callPackage ./distro/nixos/package.nix { });
  };
}
