pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Material's size grip: a tonal tab on the bottom-right corner; dragging it shows the footprint it lands on.
Item {
    id: root

    required property var widget
    readonly property bool active: area.pressed
    readonly property real tab: 26
    property real reachWidth: 0
    property real reachHeight: 0

    function sizeOf(name: string): size { return root.widget.footprintOf(name) }
    function nearest(width: real, height: real): string {
        let best = root.widget.sizeClass
        let bestDistance = Infinity
        for (const size of root.widget.sizes) {
            const target = root.sizeOf(size)
            const distance = Math.pow(width - target.width, 2) + Math.pow(height - target.height, 2)
            if (distance < bestDistance) {
                bestDistance = distance
                best = size
            }
        }
        return best
    }

    x: root.widget.width - root.tab / 2 - 2
    y: root.widget.height - root.tab / 2 - 2
    width: root.tab
    height: root.tab

    // The footprint the drag lands on, drawn from the widget's corner.
    Rectangle {
        parent: root.parent
        z: root.z - 1
        visible: opacity > 0
        opacity: root.active ? 1 : 0
        readonly property size landing: root.sizeOf(root.widget.sizeClass)
        width: landing.width
        height: landing.height
        radius: Appearance.rounding.normal
        color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.08)
        border.width: 2
        border.color: Appearance.colors.colPrimary
        Behavior on width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
        Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            width: landingLabel.implicitWidth + 20
            height: 26
            radius: height / 2
            color: Appearance.colors.colPrimary
            StyledText {
                id: landingLabel
                anchors.centerIn: parent
                text: root.widget.sizeLabels[root.widget.sizeClass] ?? ""
                color: Appearance.colors.colOnPrimary
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: root.active || area.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colPrimaryContainer
        border.width: 2
        border.color: Appearance.colors.colLayer0
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        StyledText {
            anchors.centerIn: parent
            text: (root.widget.sizeLabels[root.widget.sizeClass] ?? "").charAt(0)
            color: root.active || area.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SizeFDiagCursor
        property real startX: 0
        property real startY: 0
        property string startSize: ""

        onPressed: mouse => {
            const point = area.mapToItem(root.widget.parent, mouse.x, mouse.y)
            area.startX = point.x
            area.startY = point.y
            area.startSize = root.widget.sizeClass
            GlobalStates.selectDesktopWidget(root.widget.editInstanceKey)
            root.widget._resizePreviewValues = ({ sizeClass: area.startSize })
            root.widget._sizing = true
        }
        onPositionChanged: mouse => {
            if (!area.pressed)
                return
            const point = area.mapToItem(root.widget.parent, mouse.x, mouse.y)
            const start = root.sizeOf(area.startSize)
            const size = root.nearest(start.width + point.x - area.startX, start.height + point.y - area.startY)
            if (size !== root.widget.sizeClass)
                root.widget._resizePreviewValues = ({ sizeClass: size })
        }
        onReleased: root.widget.commitSize(root.widget.sizeClass)
        onCanceled: root.widget.commitSize(area.startSize)
    }
}
