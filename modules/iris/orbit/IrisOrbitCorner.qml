pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.frame

// The way into Orbit without a key: rest the pointer in a screen corner. It picks the corner itself unless told (Auto):
// one Niri's own overview does not already use, and where none of your pieces sits. A game, a locked screen and widget
// editing switch it off; leaving the corner re-arms it, so closing Orbit with the pointer still there does not reopen it.
Scope {
    id: root

    readonly property var options: Config.options?.iris?.orbit ?? ({})
    readonly property bool enabled: CompositorService.isNiri && (root.options.enable ?? true) && (root.options.hotCorner ?? true)
    readonly property string configured: String(root.options.hotCornerAt ?? "auto")
    readonly property int size: Math.max(4, Math.min(40, Number(root.options.hotCornerSize ?? 12)))
    readonly property int delay: Math.max(0, Math.min(600, Number(root.options.hotCornerDelay ?? 150)))
    readonly property var order: ["bottomRight", "topRight", "bottomLeft", "topLeft"]
    readonly property var zoneOf: ({ topLeft: "top-left", topRight: "top-right", bottomLeft: "bottom-left", bottomRight: "bottom-right" })

    // Where iRiS keeps pieces: a corner with one in its zone is a bad place to aim at.
    readonly property var occupiedZones: {
        const bubbles = Config.options?.iris?.bubbles ?? ({})
        const zones = new Set()
        for (const slot of ["left", "right", "utility"]) {
            const place = String(bubbles[slot]?.place ?? "")
            if (place.length > 0) zones.add(place)
        }
        const extras = bubbles.extras ?? ({})
        for (const id in extras) {
            if (IrisFrame.extraOn(extras, id)) zones.add(String(extras[id]?.place ?? ""))
        }
        return zones
    }

    function cornerFor(outputName: string): string {
        if (root.configured !== "auto")
            return NiriService.isOverviewHotCornerActive(outputName, root.configured) ? "" : (root.order.includes(root.configured) ? root.configured : "")
        const free = root.order.filter(corner => !NiriService.isOverviewHotCornerActive(outputName, corner))
        return free.find(corner => !root.occupiedZones.has(root.zoneOf[corner])) ?? free[0] ?? ""
    }

    Variants {
        model: root.enabled ? Quickshell.screens : []

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property string outputName: win.modelData?.name ?? ""
            readonly property string corner: root.cornerFor(win.outputName)
            // Armed once the pointer has been out of the corner since Orbit last opened from it.
            property bool armed: true

            visible: win.corner.length > 0 && !GameMode.active && !GlobalStates.screenLocked && !GlobalStates.widgetEditMode
                && !GlobalStates.irisOrbitOpen && !NiriService.inOverview
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:iris-orbit-corner"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: win.corner === "topLeft" || win.corner === "topRight"
                bottom: win.corner === "bottomLeft" || win.corner === "bottomRight"
                left: win.corner === "topLeft" || win.corner === "bottomLeft"
                right: win.corner === "topRight" || win.corner === "bottomRight"
            }
            implicitWidth: root.size
            implicitHeight: root.size

            Component.onCompleted: win.publish()
            onCornerChanged: win.publish()
            Component.onDestruction: {
                const next = Object.assign({}, GlobalStates.irisOrbitCorners)
                delete next[win.outputName]
                GlobalStates.irisOrbitCorners = next
            }
            function publish(): void {
                const next = Object.assign({}, GlobalStates.irisOrbitCorners)
                next[win.outputName] = win.corner
                GlobalStates.irisOrbitCorners = next
            }

            HoverHandler {
                id: hover
                onHoveredChanged: if (!hover.hovered) win.armed = true
            }
            Timer {
                interval: Math.max(1, root.delay)
                running: hover.hovered && win.armed && win.visible && root.delay > 0
                onTriggered: win.fire()
            }
            // No delay: the first hover fires.
            Connections {
                target: hover
                enabled: root.delay === 0
                function onHoveredChanged(): void { if (hover.hovered) win.fire() }
            }
            function fire(): void {
                if (!win.armed || !win.visible) return
                win.armed = false
                GlobalStates.openIrisOrbit(win.outputName)
            }
        }
    }
}
