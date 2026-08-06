pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions

Item {
    id: root

    required property string surfaceId
    required property string label
    required property color accentColor
    required property color surfaceColor
    required property color textColor
    required property real frameRadius
    required property string fontFamily
    required property int fontPixelSize
    required property int animationDuration

    property bool active: false
    property bool selected: false
    property bool lifted: false
    property bool dragEnabled: true
    // Physical slot of the window hosting this frame ("top", "right",
    // "bottom", "left") or "" for a fullscreen host window. Used together
    // with the screen dimensions to map grabbed pointer motion into
    // screen-relative coordinates for edge-zone detection.
    property string slotHint: ""
    property real screenWidth: 0
    property real screenHeight: 0

    signal activated(string surfaceId)
    signal dragStarted(string surfaceId)
    signal dragMoved(string surfaceId, real screenX, real screenY)
    signal dragEnded(string surfaceId)
    signal dragCanceled(string surfaceId)

    visible: root.active
    enabled: root.active
    z: 10000
    activeFocusOnTab: root.active

    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.description: root.lifted
        ? qsTr("Drop on a screen edge to move this shell surface")
        : root.selected
            ? qsTr("Selected shell surface. Drag to move it to another edge")
            : qsTr("Select shell surface for editing")
    Accessible.focusable: root.active

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.activated(root.surfaceId)
            event.accepted = true
        }
    }

    readonly property real _hostWindowWidth: Window.width
    readonly property real _hostWindowHeight: Window.height

    // Layer-shell windows do not expose their screen position, but every
    // participating host is either fullscreen, anchored to a known edge, or
    // centered on it, so the origin is derivable from slotHint plus sizes.
    function _screenPoint(mouseX: real, mouseY: real): var {
        const scene = frameInput.mapToItem(null, mouseX, mouseY)
        const winWidth = root._hostWindowWidth
        const winHeight = root._hostWindowHeight
        const outWidth = root.screenWidth > 0 ? root.screenWidth : winWidth
        const outHeight = root.screenHeight > 0 ? root.screenHeight : winHeight
        let originX = 0
        if (root.slotHint === "right")
            originX = outWidth - winWidth
        else if (root.slotHint !== "left")
            originX = winWidth >= outWidth - 2 ? 0 : (outWidth - winWidth) / 2
        let originY = 0
        if (root.slotHint === "bottom")
            originY = outHeight - winHeight
        else if (root.slotHint !== "top")
            originY = winHeight >= outHeight - 2 ? 0 : (outHeight - winHeight) / 2
        return { x: originX + scene.x, y: originY + scene.y }
    }

    readonly property color _accentLit: Qt.lighter(root.accentColor, 1.12)
    readonly property color _hair: ColorUtils.applyAlpha(root.textColor, 0.14)

    Rectangle {
        anchors.fill: parent
        radius: root.frameRadius
        color: ColorUtils.applyAlpha(root.accentColor,
            root.lifted ? 0.12
                : root.selected ? 0.07
                : frameInput.containsMouse ? 0.045 : 0.018)
        border.width: root.lifted || root.selected ? 2 : 1
        border.color: root.lifted
            ? root._accentLit
            : ColorUtils.applyAlpha(root.accentColor,
                root.selected ? 0.92
                    : frameInput.containsMouse ? 0.72 : 0.48)

        Behavior on color {
            enabled: root.animationDuration > 0
            ColorAnimation { duration: root.animationDuration }
        }
        Behavior on border.color {
            enabled: root.animationDuration > 0
            ColorAnimation { duration: root.animationDuration }
        }
    }

    Rectangle {
        id: labelPlate
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 8
            topMargin: 8
        }
        width: labelRow.implicitWidth + 18
        height: labelRow.implicitHeight + 11
        radius: Math.min(root.frameRadius, height / 2)
        color: root.surfaceColor
        border.width: root.selected || root.lifted ? 2 : 1
        border.color: root.selected || root.lifted
            ? ColorUtils.applyAlpha(root.accentColor, 0.82) : root._hair

        Behavior on border.color {
            enabled: root.animationDuration > 0
            ColorAnimation { duration: root.animationDuration }
        }

        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 0

            Text {
                id: labelText
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.max(0, root.width - 56))
                text: root.lifted
                    ? root.label + " · " + qsTr("Moving") : root.label
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: root.fontPixelSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
    }

    MouseArea {
        id: frameInput

        property bool dragging: false
        property real pressX: 0
        property real pressY: 0

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        preventStealing: true
        cursorShape: dragging ? Qt.ClosedHandCursor
            : root.dragEnabled ? Qt.OpenHandCursor : Qt.PointingHandCursor
        onPressed: mouse => {
            root.forceActiveFocus()
            dragging = false
            pressX = mouse.x
            pressY = mouse.y
            if (mouse.button === Qt.LeftButton)
                root.activated(root.surfaceId)
            mouse.accepted = true
        }
        onPositionChanged: mouse => {
            if (!pressed || !root.dragEnabled
                    || mouse.buttons !== Qt.LeftButton)
                return
            if (!dragging) {
                if (Math.hypot(mouse.x - pressX, mouse.y - pressY) < 9)
                    return
                dragging = true
                root.dragStarted(root.surfaceId)
            }
            const point = root._screenPoint(mouse.x, mouse.y)
            root.dragMoved(root.surfaceId, point.x, point.y)
        }
        onReleased: mouse => {
            if (dragging) {
                dragging = false
                root.dragEnded(root.surfaceId)
            }
            mouse.accepted = true
        }
        onCanceled: {
            if (dragging) {
                dragging = false
                root.dragCanceled(root.surfaceId)
            }
        }
        onWheel: wheel => { wheel.accepted = true }
    }
}
