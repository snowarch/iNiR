# Auto-imports every .nix file in this directory (except default.nix itself
# and inir-deps.nix, which is a package-list function, not a module).
# This way users can drop their own modules here (packages.nix, printing.nix,
# 99-inir-local.nix, ...) without ever touching an imports list — and the
# users can update iNiR modules without destroying custom files.
{ config, pkgs, lib, ... }:

{
  imports =
    builtins.map (f: ./${f})
      (builtins.filter (
        n: lib.hasSuffix ".nix" n && n != "default.nix" && n != "inir-deps.nix" && n != "home-manager.nix"
      ) (builtins.attrNames (builtins.readDir ./.)));
}
