{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "inir-mascot";
  version = "3";

  src = import ./mascot-pack.nix { inherit pkgs; };

  dontUnpack = true;

  installPhase = ''
    mkdir -p "$out/share/quickshell/inir/assets/images/mascot"
    tar xf "$src" -C "$out/share/quickshell/inir/assets/images/mascot/"
  '';

  meta = {
    description = "Optional Kira mascot art pack for iNiR";
    homepage = "https://github.com/snowarch/inir-mascot";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.linux;
  };
}
