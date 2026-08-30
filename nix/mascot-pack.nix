{ pkgs }:
# Shared source for the iNiR mascot art pack (poses & animations), published
# from the snowarch/inir-mascot repo. Reused by the default iNiR package
# (which embeds the sprites so it ships the mascot) and by the standalone
# inir-mascot companion package.
{
  src = pkgs.fetchurl {
    url = "https://github.com/snowarch/inir-mascot/releases/download/v3/inir-mascot-pack.tar.gz";
    hash = "sha256-DCkWHOVa/7N9FlGD+XdVBuyXRnlWf+3Kv3Lp9f9aw5s=";
  };
}
