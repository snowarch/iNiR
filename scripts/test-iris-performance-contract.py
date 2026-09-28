#!/usr/bin/env python3
"""Structural guards for iRiS lifetime/performance invariants."""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
BAR = (ROOT / "modules/iris/bar/IrisBar.qml").read_text(encoding="utf-8")
ISLAND = (ROOT / "modules/iris/bar/IrisIsland.qml").read_text(encoding="utf-8")
STAGE = (ROOT / "modules/iris/stage/IrisStage.qml").read_text(encoding="utf-8")
CONFIG = (ROOT / "modules/common/Config.qml").read_text(encoding="utf-8")
POINTER_HANDLER = re.compile(r"\bon(Translation|Position|Centroid|ActiveTranslation|MouseX|MouseY)Changed\s*:")
CONFIG_WRITE = re.compile(r"Config\.setNestedValues?\(|IrisOptions\.commit\(")


def handler_body(text: str, start: int) -> str:
    rest = text[start:].lstrip()
    if not rest.startswith("{"):
        return rest.split("\n", 1)[0]
    depth = 0
    for i, ch in enumerate(rest):
        depth += ch == "{"
        depth -= ch == "}"
        if depth == 0:
            return rest[: i + 1]
    return rest


BEHAVIOUR = re.compile(r"Behavior on [\w.]+\s*\{\s*(?:NumberAnimation|ColorAnimation)\s*\{([^{}]*)\}")


def linear_behaviours() -> list[str]:
    found = []
    for path in sorted((ROOT / "modules/iris").rglob("*.qml")):
        text = path.read_text(encoding="utf-8")
        for match in BEHAVIOUR.finditer(text):
            if "easing" not in match.group(1):
                found.append(f"{path.relative_to(ROOT)}:{text.count(chr(10), 0, match.start()) + 1}")
    return found


def pointer_config_writes() -> list[str]:
    found = []
    for path in sorted((ROOT / "modules/iris").rglob("*.qml")):
        text = path.read_text(encoding="utf-8")
        for match in POINTER_HANDLER.finditer(text):
            if CONFIG_WRITE.search(handler_body(text, match.end())):
                line = text.count("\n", 0, match.start()) + 1
                found.append(f"{path.relative_to(ROOT)}:{line}")
    return found


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def main() -> int:
    failures: list[str] = []

    require(
        'readonly property bool panelMode: String(Config.options?.iris?.controlCenter?.opens ?? "island") !== "island"' in BAR,
        "external Control Center is no longer gated by panel mode", failures)
    require(
        'GlobalStates.irisMorphOwner === "stage"' in BAR and "controlCentreLoader.externalOpen" in BAR,
        "Stage-origin Control Center path is not preserved", failures)
    require(
        "stage.controlIntent" in BAR and "readonly property bool controlIntent:" in STAGE,
        "floating Controls/Battery intent no longer prewarms the external body", failures)
    require(
        "controlCentreLoader.releaseTimer" in BAR and "controlCentreLoader.resident" in BAR,
        "external Control Center no longer has finite residency", failures)
    require(
        "controlCentreLoader.kept" not in BAR,
        "external Control Center reverted to permanent kept residency", failures)

    require(
        "active: (root.rects[bubbleSlot.index] ?? null) !== null" in STAGE,
        "Stage no longer loads resting bubbles only for floating slots", failures)
    require(
        "model: root.allSlots\n        FloatingBubble" not in STAGE,
        "Stage recreated a FloatingBubble for every registry slot", failures)
    require(
        "Component.onCompleted: bubble.settle()" in STAGE,
        "a lazily created floating bubble never reports its centre or enables move motion", failures)

    require(
        "value: !root.controlsInIsland && (root.pointerOnIsland || root.expanded)" in ISLAND,
        "Island-mode Control Center still warms the external panel", failures)
    require(
        "value: root.settingsIntent" in ISLAND,
        "Settings warm state is no longer driven by explicit intent", failures)
    settings_binding = ISLAND.split('property: "irisSettingsWarm"', 1)[1].split("}", 1)[0]
    require(
        "value: root.settingsIntent" in settings_binding and "value: root.expanded" not in settings_binding,
        "generic Island expansion warms Settings again", failures)
    require(
        "readonly property bool resident: pageItem.current || pageItem.opacity > 0.004" in ISLAND,
        "Island pages lost page-level residency", failures)

    for page_id in ("trayLoader", "controlsLoader", "toolsLoader", "mediaLoader", "activityLoader", "desktopLoader"):
        require(f"id: {page_id}" in ISLAND, f"missing lazy page body {page_id}", failures)

    for where in linear_behaviours():
        failures.append(f"{where}: a Behavior with no easing is linear; use IrisStyle.feedbackEasing or a motion curve")

    for where in pointer_config_writes():
        failures.append(f"{where}: writes the config per pointer event; push through IrisConfigDrag")

    taken = ISLAND.split("function pieceTaken(", 1)[1].split("\n    }", 1)[0]
    require(
        "SatelliteShown" not in taken and "auxiliaryShown" not in taken,
        "pieceTaken reads a shown state that flips on expand, so every open rebuilds the bar pieces", failures)
    require(
        'joins: !extension.anchoredShape || floating ? ""' in ISLAND,
        "the inline page fuses into the chassis rectangle it equals, swelling the silhouette", failures)
    require(
        "rawConfigReader.text() === configFileView.text()" in CONFIG,
        "Config reloads its own saves again instead of only external changes", failures)

    if failures:
        print("iRiS performance contract failures:")
        for failure in failures:
            print(f"  {failure}")
        return 1

    print("iRiS performance contract: lifetime guards intact")
    return 0


if __name__ == "__main__":
    sys.exit(main())
