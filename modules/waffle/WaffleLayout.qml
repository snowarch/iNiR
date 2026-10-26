import QtQuick
import qs.modules.common

// Waffle's persistent surfaces for ShellLayoutController: the taskbar, top or bottom.
QtObject {
    readonly property var surfaces: [
        {
            id: "waffleBar",
            families: ["waffle"],
            kind: "edge",
            labelKey: "Taskbar",
            icon: "desktop_windows",
            layoutScope: "enabledOutputs",
            slots: ["top", "bottom"],
            editableProperties: [],
            collisionPolicy: "validated",
            resetScopes: ["surface", "family"]
        }
    ]
    readonly property var rebuilds: ["waffleBar"]

    function surfaceState(surfaceId: string, desc: var, outputName: string): var {
        if (surfaceId !== "waffleBar")
            return null
        return {
            ok: true,
            id: surfaceId,
            slot: (Config.options?.waffles?.bar?.bottom ?? true) ? "bottom" : "top",
            scope: desc.layoutScope,
            outputName: outputName,
            enabledOutputs: Config.options?.waffles?.bar?.screenList ?? [],
            source: "waffles.bar.bottom"
        }
    }
    function moveSurface(surfaceId: string, slot: string): bool {
        if (surfaceId !== "waffleBar")
            return false
        Config.setNestedValue("waffles.bar.bottom", slot === "bottom")
        return true
    }
    function resetSlot(surfaceId: string): string { return surfaceId === "waffleBar" ? "bottom" : "" }
}
