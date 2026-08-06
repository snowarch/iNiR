pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

// ZZZ surface treatment: thin poster registration rail plus opt-in role sticker.
// Put it inside a clipped Rectangle/Item; it costs no delegates when inactive.
Item {
    id: root

    anchors.fill: parent

    property bool showTape: true
    property bool showSticker: false
    property int stripeCount: 18
    property int tapeHeight: Appearance.zzz.borderThick * 2
    property int stickerWidth: 38
    property int stickerHeight: 12
    property int edgeMargin: 0
    // Round the rail's top corners to follow the host surface silhouette.
    property int cornerRadius: Appearance.zzz.panelRadius

    readonly property bool active: Appearance.zzzEverywhere
    readonly property int railHeight: Math.max(2, Math.min(tapeHeight, Appearance.zzz.borderThick * 2))

    visible: opacity > 0 || tape.height > 0
    opacity: active ? 1 : 0
    clip: true

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Item {
        id: tape
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.edgeMargin
        anchors.rightMargin: root.edgeMargin
        height: root.active && root.showTape ? root.railHeight : 0
        clip: true

        Behavior on height {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }

        Rectangle {
            anchors.fill: parent
            topLeftRadius: Math.max(0, root.cornerRadius - root.edgeMargin)
            topRightRadius: Math.max(0, root.cornerRadius - root.edgeMargin)
            color: Appearance.zzz.registrationRail
        }

        Repeater {
            model: root.active && root.showTape ? Math.min(root.stripeCount, Math.ceil(Math.max(1, tape.width) / 78) + 2) : 0
            Rectangle {
                required property int index
                width: index % 4 === 0 ? 28 : index % 2 === 0 ? 14 : 8
                height: tape.height
                x: index * 78
                color: index % 3 === 0 ? Appearance.zzz.registrationMark : Appearance.zzz.registrationMarkAlt
            }
        }
    }

    Rectangle {
        id: sticker
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.edgeMargin + tape.height + 6
        anchors.rightMargin: root.edgeMargin + 8
        width: root.active && root.showSticker ? root.stickerWidth : 0
        height: root.stickerHeight
        radius: Appearance.zzz.cornerRadius
        color: Appearance.zzz.posterCool

        Behavior on width {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }
}
