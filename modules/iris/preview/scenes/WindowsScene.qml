pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Niri's strip as it tiles: three columns with the gaps between them, the focused one in its ring or border, corners,
// shadows and the opacity of the windows you are not using, all read from Niri itself.
PreviewScene {
    id: winRoot
    function colourOf(value: var, fallback: color): color { return String(value ?? "").length > 0 ? value : fallback }
    readonly property real gaps: Math.max(0, Number(winRoot.niri("layout", "gaps", 16)))
    readonly property bool border: winRoot.niri("layout", "border.enabled", false) === true
    readonly property real borderWidth: Number(winRoot.niri("layout", "border.width", 4))
    readonly property bool ring: winRoot.niri("layout", "focus-ring.enabled", false) === true
    readonly property real ringWidth: Number(winRoot.niri("layout", "focus-ring.width", 4))
    readonly property color ringColour: winRoot.colourOf(winRoot.niri("layout", "focus-ring.active-color", ""), IrisStyle.accent)
    readonly property color borderOn: winRoot.colourOf(winRoot.niri("layout", "border.active-color", ""), IrisStyle.accent)
    readonly property color borderOff: winRoot.colourOf(winRoot.niri("layout", "border.inactive-color", ""), IrisStyle.borderStrong)
    readonly property real corners: Math.max(0, Number(winRoot.niri("window-rules", "corner-radius", 0)))
    readonly property bool shadows: winRoot.niri("layout", "shadow.enabled", false) === true
    readonly property real softness: Number(winRoot.niri("layout", "shadow.softness", 30))
    readonly property real dim: Math.max(0.2, Math.min(1, Number(winRoot.niri("window-rules", "inactive-opacity", 1))))
    readonly property real naturalWidth: Math.round(680 * winRoot.d)
    readonly property real naturalHeight: Math.round(320 * winRoot.d)

    Repeater {
        // The column on the left runs off the screen as Niri's strip does; the focused one sits in the middle.
        model: [{ x: -0.16, w: 0.34, focused: false }, { x: 0.18, w: 0.46, focused: true }, { x: 0.64, w: 0.42, focused: false }]
        Item {
            id: column
            required property var modelData
            readonly property real g: winRoot.gaps
            x: Math.round(winRoot.width * column.modelData.x + column.g / 2)
            y: Math.round(column.g + IrisStyle.weld)
            width: Math.round(winRoot.width * column.modelData.w - column.g)
            height: Math.round(winRoot.height - 2 * column.g - IrisStyle.weld)
            opacity: column.modelData.focused ? 1 : winRoot.dim

            RectangularShadow {
                visible: winRoot.shadows
                anchors.fill: app
                radius: app.radius
                blur: winRoot.softness * 0.6 * winRoot.d
                offset.y: 3 * winRoot.d
                color: IrisStyle.shadow
            }
            // The ring sits outside the focused window, as Niri draws it.
            Rectangle {
                visible: winRoot.ring && column.modelData.focused
                anchors.fill: app
                anchors.margins: -winRoot.ringWidth
                radius: app.radius + winRoot.ringWidth
                color: "transparent"
                border.width: winRoot.ringWidth
                border.color: winRoot.ringColour
            }
            Rectangle {
                id: app
                anchors.fill: parent
                radius: winRoot.corners
                // An app window is opaque whatever the shell's glass: the theme's own surface.
                color: IrisStyle.surfaceOpaque
                border.width: winRoot.border ? winRoot.borderWidth : 0
                border.color: column.modelData.focused ? winRoot.borderOn : winRoot.borderOff
                Column {
                    x: Math.round(14 * winRoot.d) + (winRoot.border ? winRoot.borderWidth : 0)
                    y: Math.round(14 * winRoot.d) + (winRoot.border ? winRoot.borderWidth : 0)
                    width: parent.width - 2 * x
                    spacing: Math.round(8 * winRoot.d)
                    Row {
                        spacing: Math.round(6 * winRoot.d)
                        Repeater {
                            model: 3
                            Rectangle { width: Math.round(8 * winRoot.d); height: width; radius: width / 2; color: IrisStyle.fillStrong }
                        }
                    }
                    Repeater {
                        model: [0.82, 0.64, 0.74, 0.4]
                        Rectangle {
                            required property real modelData
                            width: Math.round(parent.width * modelData)
                            height: Math.round(6 * winRoot.d)
                            radius: height / 2
                            color: IrisStyle.fill
                        }
                    }
                }
            }
        }
    }

    Caption {
        glyph: "select_window"
        text: [Translation.tr("Gaps") + " " + Math.round(winRoot.gaps) + " px",
            winRoot.corners > 0 ? Translation.tr("Window corners") + " " + Math.round(winRoot.corners) + " px" : "",
            winRoot.ring ? Translation.tr("Focus ring") : winRoot.border ? Translation.tr("Border") : ""].filter(part => part.length > 0).join(" · ")
    }
}
