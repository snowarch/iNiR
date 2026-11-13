pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// One live snip: the window's rectangle streamed, its controls over the top edge while the pointer is on it. Drag moves
// it, the corner grip resizes it keeping its crop, a quick click goes to the window. The host places it at liveX/liveY.
Item {
    id: card
    required property string pinId
    // Where it may go: the screen it is on.
    property size bounds: Qt.size(1920, 1080)

    readonly property var pin: LivePins.find(card.pinId)
    readonly property var win: LivePins.windowOf(card.pinId)
    readonly property bool live: card.win !== null
    readonly property string appName: {
        const entry = AppSearch.lookupDesktopEntry(card.pin?.appId ?? "")
        return String(entry?.name ?? card.pin?.appId ?? "")
    }
    readonly property string appIcon: {
        const id = card.pin?.appId ?? ""
        return AppSearch.lookupDesktopEntry(id)?.icon || AppSearch.guessIcon(id)
    }
    readonly property real aspect: {
        const crop = card.pin?.crop ?? [0, 0, 16, 9]
        return Math.max(1, crop[3]) / Math.max(1, crop[2])
    }

    property bool moving: false
    property bool sizing: false
    property bool closing: false
    property real liveX: Number(card.pin?.x ?? 80)
    property real liveY: Number(card.pin?.y ?? 120)
    property real liveWidth: Number(card.pin?.width ?? 320)
    readonly property real radius: Appearance.rounding.normal
    readonly property bool chrome: cardMouse.containsMouse || card.moving || card.sizing

    width: Math.round(card.liveWidth)
    height: Math.round(card.liveWidth * card.aspect)

    // The stored spot follows the file unless the pointer holds the card.
    onPinChanged: {
        if (!card.pin || card.moving || card.sizing) return
        card.liveX = Number(card.pin.x)
        card.liveY = Number(card.pin.y)
        card.liveWidth = Number(card.pin.width)
    }

    function close(): void {
        card.closing = true
        removeLater.restart()
    }
    Timer {
        id: removeLater
        interval: Appearance.animation.elementMoveFast.duration
        onTriggered: LivePins.remove(card.pinId)
    }

    // Pops in from where it was cut, shrinks away when closed.
    property bool arrived: false
    Component.onCompleted: card.arrived = true
    opacity: card.arrived && !card.closing ? 1 : 0
    scale: card.arrived && !card.closing ? 1 : 0.9
    Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    Behavior on scale { NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

    StyledRectangularShadow { target: card }

    ClippingRectangle {
        anchors.fill: parent
        radius: card.radius
        color: Qt.rgba(0.08, 0.08, 0.09, 0.92)

        LiveWindowCrop {
            id: crop
            anchors.fill: parent
            windowId: card.win?.id ?? -1
            crop: {
                const c = card.pin?.crop ?? [0, 0, 0, 0]
                return Qt.rect(c[0], c[1], c[2], c[3])
            }
            base: {
                const b = card.pin?.base ?? [0, 0]
                return Qt.size(b[0], b[1])
            }
            windowSize: {
                const s = card.win?.layout?.window_size ?? [0, 0]
                return Qt.size(Number(s[0]), Number(s[1]))
            }
            active: card.live && !card.closing && card.visible
        }

        // The window is gone (or its picture has not come yet): who it was and how to bring it back.
        Column {
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 6
            opacity: crop.streaming ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
            IconImage {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: card.height >= 96
                implicitSize: 28
                source: Quickshell.iconPath(card.appIcon, "application-x-executable")
            }
            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: card.live ? Translation.tr("Waiting for %1").arg(card.appName)
                    : Translation.tr("%1 is closed").arg(card.appName)
                color: "white"
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            StyledText {
                width: parent.width
                visible: !card.live && card.height >= 72
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Click to open it again")
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        // Controls over the top edge while the pointer is on the card, as a picture in picture does.
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 36
            color: Qt.rgba(0, 0, 0, 0.5)
            opacity: card.chrome ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            Row {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 7
                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 16
                    source: Quickshell.iconPath(card.appIcon, "application-x-executable")
                }
                // What the icon and the buttons leave; at the narrowest the icon says it alone.
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, Math.min(implicitWidth, card.width - 10 - 16 - 7 - 8 - buttons.width - 6))
                    visible: width >= 24
                    text: card.appName
                    color: "white"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
            Row {
                id: buttons
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 2
                PinButton {
                    icon: "keep"
                    on: card.pin?.onTop ?? false
                    tip: (card.pin?.onTop ?? false) ? Translation.tr("Keep on the desktop") : Translation.tr("Keep above windows")
                    onActivated: LivePins.update(card.pinId, { onTop: !(card.pin?.onTop ?? false) })
                }
                PinButton {
                    icon: "close"
                    tip: Translation.tr("Remove pin")
                    onActivated: card.close()
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, card.chrome ? 0.22 : 0.12)
        Behavior on border.color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
    }

    // Move and click, measured in window coordinates from the press: on the desktop the window stays still; above the
    // windows the card's own window moves, and niri keeps a press's coordinates relative to where that window was.
    // Only a quick click goes to the window: a press held to take the card and let go in place leaves it be.
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: card.moving ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property point press: Qt.point(0, 0)
        property point start: Qt.point(0, 0)
        property real pressedAt: 0
        property bool dragged: false
        onPressed: mouse => {
            cardMouse.press = cardMouse.mapToItem(null, mouse.x, mouse.y)
            cardMouse.start = Qt.point(card.liveX, card.liveY)
            cardMouse.pressedAt = Date.now()
            cardMouse.dragged = false
        }
        onPositionChanged: mouse => {
            if (!cardMouse.pressed) return
            const at = cardMouse.mapToItem(null, mouse.x, mouse.y)
            const dx = at.x - cardMouse.press.x, dy = at.y - cardMouse.press.y
            if (!card.moving && Math.abs(dx) + Math.abs(dy) < 5) return
            card.moving = true
            cardMouse.dragged = true
            card.liveX = Math.max(-card.width + 48, Math.min(card.bounds.width - 48, cardMouse.start.x + dx))
            card.liveY = Math.max(0, Math.min(card.bounds.height - 48, cardMouse.start.y + dy))
        }
        onReleased: {
            if (!card.moving) return
            card.moving = false
            LivePins.update(card.pinId, { x: Math.round(card.liveX), y: Math.round(card.liveY) })
        }
        onClicked: if (!cardMouse.dragged && Date.now() - cardMouse.pressedAt < 350) LivePins.activate(card.pinId)
    }

    // The corner grip: width follows the pointer, height follows the crop. The card grows from its top left corner,
    // which neither host moves while it does.
    MouseArea {
        id: grip
        width: 26
        height: 26
        anchors { right: parent.right; bottom: parent.bottom }
        hoverEnabled: true
        cursorShape: Qt.SizeFDiagCursor
        property real pressX: 0
        property real startWidth: 0
        onPressed: mouse => {
            grip.pressX = grip.mapToItem(null, mouse.x, mouse.y).x
            grip.startWidth = card.liveWidth
            card.sizing = true
        }
        onPositionChanged: mouse => {
            if (!grip.pressed) return
            const dx = grip.mapToItem(null, mouse.x, mouse.y).x - grip.pressX
            card.liveWidth = Math.max(LivePins.minWidth, Math.min(LivePins.maxWidth, grip.startWidth + dx))
        }
        onReleased: {
            card.sizing = false
            LivePins.update(card.pinId, { width: Math.round(card.liveWidth) })
        }
        Canvas {
            anchors.fill: parent
            anchors.margins: 7
            opacity: card.chrome ? 0.85 : 0
            Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "white"
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(width, height * 0.25); ctx.lineTo(width * 0.25, height)
                ctx.moveTo(width, height * 0.65); ctx.lineTo(width * 0.65, height)
                ctx.stroke()
            }
        }
    }

    component PinButton: MouseArea {
        id: button
        property string icon: ""
        property string tip: ""
        property bool on: false
        signal activated()
        width: 28
        height: 28
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: button.tip
        onClicked: button.activated()
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(1, 1, 1, button.on ? 0.28 : button.containsMouse ? 0.16 : 0)
            Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: button.icon
            iconSize: 17
            fill: button.on ? 1 : 0
            color: "white"
        }
    }
}
