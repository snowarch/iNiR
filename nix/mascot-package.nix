{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "inir-mascot";
  version = "3";

  src = (import ./mascot-pack.nix { inherit pkgs; }).src;

  dontUnpack = true;

  installPhase = ''
    mkdir -p "$out/share/quickshell/inir/assets/images/mascot"
    tar xf "$src" -C "$out/share/quickshell/inir/assets/images/mascot/"
  '';

  meta = {
    description = "iNiR mascot art pack (354 poses/animations)";
    homepage = "https://github.com/snowarch/inir-mascot";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.linux;
  };
}
