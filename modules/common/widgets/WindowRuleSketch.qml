pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import qs.services

// Where and how an app's windows open, drawn: a screen wearing the wallpaper, the workspace they land on (marks down
// its left), and the window as it opens (a column of its width beside the next one, floating, maximized or the whole
// screen), as see-through as the rule says. Geometry only: each family's App rules dresses it with its own colours,
// radii and motion, and draws its marks (left out of captures, a named workspace) over `window` as children.
Item {
    id: root

    property var rule: null
    property string icon: ""
    property real unit: 1
    property real radius: 8 * root.unit
    property real windowRadius: 6 * root.unit
    property color windowColor: "#e0e0e0"
    property color lineColor: "#33000000"
    property int duration: 260
    property int easing: Easing.OutCubic
    property list<real> curve: []
    readonly property alias window: win
    default property alias marks: over.data

    readonly property string open: String(root.rule?.open ?? "")
    readonly property real share: Number(root.rule?.width ?? 0) > 0 ? Number(root.rule.width) : 0.5
    readonly property bool named: String(root.rule?.workspace ?? "").length > 0
    readonly property real gap: Math.round(6 * root.unit)

    Item {
        id: glass
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle { width: glass.width; height: glass.height; radius: root.radius }
        }

        Image {
            anchors.fill: parent
            source: Wallpapers.effectiveWallpaperUrl
            sourceSize.width: Math.round(420 * root.unit)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }

        // The workspace it lands on: a stack of them down the left, the one it opens on lit.
        Column {
            x: root.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(4 * root.unit)
            visible: root.open !== "fullscreen"
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    readonly property bool here: typeof root.rule?.workspace === "number" ? root.rule.workspace - 1 === index : index === 0
                    width: Math.round(4 * root.unit)
                    height: here ? Math.round(14 * root.unit) : Math.round(6 * root.unit)
                    radius: width / 2
                    color: "#ffffff" // marks over a wallpaper, never a theme's ink
                    opacity: here && root.named ? 1 : 0.45
                    Behavior on height { NumberAnimation { duration: root.duration; easing.type: root.easing; easing.bezierCurve: root.curve } }
                }
            }
        }

        // The column after it on the strip: the windows that were already there.
        Rectangle {
            visible: root.open === "" || root.open === "tiled"
            x: win.x + win.width + root.gap
            y: root.gap
            width: glass.width * 0.5
            height: glass.height - root.gap * 2
            radius: root.windowRadius
            color: root.windowColor
            opacity: 0.45
        }

        Rectangle {
            id: win
            readonly property real inset: Math.round(14 * root.unit)
            x: root.open === "fullscreen" ? 0 : root.open === "floating" ? (glass.width - win.width) / 2 : inset
            y: root.open === "fullscreen" ? 0 : root.open === "floating" ? glass.height * 0.2 : root.gap
            width: root.open === "fullscreen" ? glass.width : root.open === "maximized" ? glass.width - inset - root.gap
                : Math.max(Math.round(48 * root.unit), (glass.width - inset) * root.share - root.gap)
            height: root.open === "fullscreen" ? glass.height : root.open === "floating" ? glass.height * 0.6 : glass.height - root.gap * 2
            radius: root.open === "fullscreen" ? 0 : root.windowRadius
            color: root.windowColor
            opacity: Number(root.rule?.opacity ?? 1)
            Behavior on x { NumberAnimation { duration: root.duration; easing.type: root.easing; easing.bezierCurve: root.curve } }
            Behavior on y { NumberAnimation { duration: root.duration; easing.type: root.easing; easing.bezierCurve: root.curve } }
            Behavior on width { NumberAnimation { duration: root.duration; easing.type: root.easing; easing.bezierCurve: root.curve } }
            Behavior on height { NumberAnimation { duration: root.duration; easing.type: root.easing; easing.bezierCurve: root.curve } }
            Behavior on opacity { NumberAnimation { duration: root.duration; easing.type: root.easing; easing.bezierCurve: root.curve } }

            // A window's face (its lines of text), so how see-through it is reads against the wallpaper.
            Column {
                x: Math.round(10 * root.unit)
                y: Math.round(10 * root.unit)
                spacing: Math.round(6 * root.unit)
                visible: win.height > Math.round(56 * root.unit)
                Repeater {
                    model: [0.62, 0.44, 0.54]
                    Rectangle {
                        required property real modelData
                        width: Math.max(0, (win.width - Math.round(20 * root.unit)) * modelData)
                        height: Math.round(4 * root.unit)
                        radius: height / 2
                        color: root.lineColor
                    }
                }
            }
            Image {
                id: appIcon
                anchors.horizontalCenter: parent.horizontalCenter
                // Under the face's lines on a short window, in the middle of a tall one.
                y: Math.max(Math.round(40 * root.unit), (win.height - appIcon.height) / 2)
                width: Math.round(Math.min(32 * root.unit, parent.height * 0.4))
                height: width
                sourceSize: Qt.size(64, 64)
                source: root.icon
                visible: root.icon.length > 0
                asynchronous: true
            }
        }

        Item {
            id: over
            anchors.fill: parent
        }
    }
}
