{
  description = "iNiR desktop shell for Niri, packaged for NixOS and Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # the commit the package names in its version.json (`inir version`, the update notice)
      commit = self.shortRev or self.dirtyShortRev or "unknown";
      nixosModule = import ./nix/nixos-module.nix { inherit commit; };
      homeModule = import ./nix/home-module.nix { inherit commit; };
    in
    {
      packages = forAllSystems (pkgs:
        let
          package = pkgs.callPackage ./nix/package.nix { inherit pkgs commit; };
          mascotPackage = pkgs.callPackage ./nix/mascot-package.nix { inherit pkgs; };
          packageWithMascot = pkgs.symlinkJoin {
            name = "inir-with-mascot-${package.version}";
            paths = [ package mascotPackage ];
          };
        in
        {
          default = package;
          inir = package;
          inir-mascot = mascotPackage;
          inir-with-mascot = packageWithMascot;
          inir-webengine = package.override { withWebEngine = true; };
        });

      nixosModules.default = nixosModule;
      nixosModules.inir = nixosModule;

      homeModules.default = homeModule;
      homeModules.inir = homeModule;

      # Conventional alias most Home Manager setups look for.
      homeManagerModules.default = homeModule;
      homeManagerModules.inir = homeModule;

      overlays.default = final: _prev: {
        inir = final.callPackage ./nix/package.nix { pkgs = final; inherit commit; };
        inir-mascot = final.callPackage ./nix/mascot-package.nix { pkgs = final; };
      };

      templates.default = {
        path = ./nix/template;
        description = "A NixOS system with Niri and iNiR";
      };

      checks = forAllSystems (pkgs:
        let
          missing = (import ./nix/deps.nix { inherit pkgs; }).missing;
        in
        {
          inir = self.packages.${pkgs.stdenv.hostPlatform.system}.inir;
          # every dep of sdata/deps.toml has its NixOS line in nix/deps.nix
          deps = assert lib.assertMsg (missing.notHere == [ ] && missing.leftOver == [ ])
            "nix/deps.nix: not here ${toString missing.notHere}; left over ${toString missing.leftOver}";
            pkgs.emptyFile;
        });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
