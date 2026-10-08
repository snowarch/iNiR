#!/usr/bin/env python3
"""iRiS Settings previews: the dispatcher and its scenes stay in step.

`IrisGroupPreview.qml` maps a scene key to a `Component` wrapping a file in `preview/scenes/`. The map is one object
literal, so a single id it names that does not exist throws and every preview goes blank, with nothing on screen to
say why. This checks each scene in the scenes qmldir is wrapped once, each wrapped id is in the map, every key
`sceneFor` returns is in the map, and every scene file sits on `PreviewScene`.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PREVIEW = ROOT / "modules" / "iris" / "preview"
DISPATCHER = (PREVIEW / "IrisGroupPreview.qml").read_text()
QMLDIR = (PREVIEW / "scenes" / "qmldir").read_text()

errors = []
scenes = re.findall(r"^(\w+Scene) [\d.]+ \1\.qml$", QMLDIR, re.M)
wrapped = dict(re.findall(r"Component \{ id: (\w+); (\w+Scene) \{ preview: root \} \}", DISPATCHER))
map_body = re.search(r"sourceComponent: \(\{(.*?)\}\)\[root\.scene\]", DISPATCHER, re.S)
mapped = dict(re.findall(r"(\w+): (\w+)", map_body.group(1))) if map_body else {}
returned = set(re.findall(r'"(\w+)"', DISPATCHER[DISPATCHER.index("function sceneFor"):DISPATCHER.index("radius:")])) \
    - set(re.findall(r'"(\w+)":', DISPATCHER))

if not scenes:
    errors.append("no scenes listed in preview/scenes/qmldir")
if not mapped:
    errors.append("IrisGroupPreview: sourceComponent map not found")
for scene in scenes:
    if list(wrapped.values()).count(scene) != 1:
        errors.append(f"{scene}: wrapped {list(wrapped.values()).count(scene)} times in IrisGroupPreview (want 1)")
    text = (PREVIEW / "scenes" / f"{scene}.qml").read_text()
    if not re.search(r"^PreviewScene \{$", text, re.M):
        errors.append(f"{scene}.qml: root object is not PreviewScene")
for cid, scene in wrapped.items():
    if scene not in scenes:
        errors.append(f"{cid}: wraps {scene}, which preview/scenes/qmldir does not list")
for key, cid in mapped.items():
    if cid not in wrapped:
        errors.append(f"map key {key}: {cid} is not a Component id in IrisGroupPreview")
for cid in wrapped:
    if cid not in mapped.values():
        errors.append(f"{cid}: wrapped but never in the sourceComponent map")
for key in sorted(returned):
    if key not in mapped:
        errors.append(f"sceneFor returns {key!r}, which the sourceComponent map lacks")

if errors:
    print("iRiS preview scenes:\n  " + "\n  ".join(errors))
    sys.exit(1)
print(f"iRiS preview scenes: {len(scenes)} scenes wrapped and mapped")
