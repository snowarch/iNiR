{ pkgs }:

# Keep this pinned to a published inir-mascot release. New shell behavior may
# adopt newer art locally first, but this tag/hash is bumped only after the
# corresponding mascot release exists so Nix remains reproducible.
pkgs.fetchurl {
  url = "https://github.com/snowarch/inir-mascot/releases/download/v3/inir-mascot-pack.tar.gz";
  hash = "sha256-DCkWHOVa/7N9FlGD+XdVBuyXRnlWf+3Kv3Lp9f9aw5s=";
}
