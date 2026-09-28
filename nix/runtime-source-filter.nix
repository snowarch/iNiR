# Keep private/local and source-only tooling out of the derivation source as well
# as the installed payload. Uses the same content policy as the other installers.
{ lib, root }:
let
  policy = builtins.fromJSON (builtins.readFile (root + "/sdata/runtime-exclusions.json"));
  prefix = toString root + "/";
  readList = name: lib.filter (s: s != "" && !(lib.hasPrefix "#" s))
    (lib.splitString "\n" (builtins.readFile (root + ("/sdata/" + name))));
  runtimeDirs = readList "runtime-payload-dirs.txt";
  runtimeFiles = readList "runtime-root-files.txt" ++ [ "LICENSE" "NOTICE" ];
  excludedName = name:
    builtins.elem name policy.excludedNames
    || lib.any (p: lib.hasPrefix p name) policy.excludedNamePrefixes
    || lib.any (s: lib.hasSuffix s name) policy.excludedNameSuffixes;
in
path: type:
let
  relative = lib.removePrefix prefix (toString path);
  parent = builtins.dirOf relative;
  suffixes = policy.excludedDirectorySuffixes.${parent} or [];
in
(builtins.elem relative runtimeFiles
 || (builtins.baseNameOf relative == relative && lib.hasSuffix ".qml" relative)
 || lib.any (p: relative == p || lib.hasPrefix (p + "/") relative) runtimeDirs)
&& lib.cleanSourceFilter path type
&& !(lib.any excludedName (lib.splitString "/" relative))
&& !(lib.any (p: relative == p || lib.hasPrefix (p + "/") relative) policy.excludedPaths)
&& !(lib.any (s: lib.hasSuffix s relative) suffixes)
