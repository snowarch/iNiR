#!/usr/bin/env python3
"""iRiS Designs dress the engine; they never stand beside it.

A Design (`modules/iris/designs/<id>/Design.qml`) brings skins, scenes and parts that iRiS's owners load in their own
place. A part that replaces an engine body (the Island, the dock, the Stage, the frame) loses everything that body
does: pages, activities, pieces, the field and its joins. AIRISU's bar did that in 2026-10 and the Island became a
player that only paused music. This checks every Design: each part's file exists, each part key is read by an owner
outside `designs/` (`IrisDesign.skin("key")`, `has("key")` or an `IrisSkin { part }`), and no part names an engine body.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
IRIS = ROOT / "modules" / "iris"
ENGINE_BODIES = {"bar", "island", "dock", "stage", "frame", "field"}

consumers = set()
for path in IRIS.rglob("*.qml"):
    if "designs" in path.relative_to(IRIS).parts:
        continue
    text = path.read_text(errors="ignore")
    consumers.update(re.findall(r'IrisDesign\.(?:skin|has)\("(\w+)"', text))
    consumers.update(re.findall(r'IrisSkin \{[^}]*?part: "(\w+)"', text))

errors = []
for manifest in sorted(IRIS.glob("designs/*/Design.qml")):
    text = manifest.read_text()
    body = re.search(r"property var parts: \(\{(.*?)\}\)", text, re.S)
    if not body:
        continue
    for key, rel in re.findall(r"(\w+): \"([^\"]+\.qml)\"", body.group(1)):
        name = f"{manifest.parent.name}.{key}"
        if key in ENGINE_BODIES:
            errors.append(f"{name}: replaces the engine body '{key}'; skin its pieces inside the owner instead")
        if not (manifest.parent / rel).exists():
            errors.append(f"{name}: {rel} does not exist")
        if key not in consumers:
            errors.append(f"{name}: no owner reads IrisDesign.skin(\"{key}\"), the part never shows")

if errors:
    print("iRiS Designs:\n  " + "\n  ".join(errors))
    sys.exit(1)
print("iRiS Designs: ok")
