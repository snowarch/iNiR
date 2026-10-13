{ config, pkgs, lib, inir ? null, ... }:

let
  cfg = config.programs.inir.mascot;

  defaultMascotPackage =
    if inir != null && builtins.pathExists "${inir}/nix/mascot-package.nix"
    then pkgs.callPackage "${inir}/nix/mascot-package.nix" { inherit pkgs; }
    else pkgs.stdenvNoCC.mkDerivation {
      pname = "inir-mascot";
      version = "3";
      src = pkgs.fetchurl {
        url = "https://github.com/snowarch/inir-mascot/releases/download/v3/inir-mascot-pack.tar.gz";
        hash = "sha256-DCkWHOVa/7N9FlGD+XdVBuyXRnlWf+3Kv3Lp9f9aw5s=";
      };
      dontUnpack = true;
      installPhase = ''
        mkdir -p "$out/share/quickshell/inir/assets/images/mascot"
        tar xf "$src" -C "$out/share/quickshell/inir/assets/images/mascot/"
      '';
      meta = {
        description = "Paquete de arte opcional de la mascota Kira para iNiR";
        homepage = "https://github.com/snowarch/inir-mascot";
        license = pkgs.lib.licenses.mit;
        platforms = pkgs.lib.platforms.linux;
      };
    };
in
{
  options.programs.inir.mascot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Habilita el paquete de arte de la mascota oficial de iNiR (Kira).
        Incluye todas las animaciones (GIF), poses estáticas (PNG) y catálogo
        para el compañero de escritorio, estados vacíos, widgets de fondo y reacciones.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultMascotPackage;
      defaultText = lib.literalExpression "pkgs.callPackage \"\${inir}/nix/mascot-package.nix\" { inherit pkgs; }";
      description = "Paquete que contiene los recursos gráficos y animaciones de la mascota.";
    };
  };

  config = lib.mkIf (cfg.enable && !(config.programs.inir.enable or false)) {
    # Expone el paquete únicamente si programs.inir no está activo (en caso activo, inir.nix lo fusiona en inirPackage)
    environment.systemPackages = [
      cfg.package
    ];
  };
}
