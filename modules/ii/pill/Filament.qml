pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

/**
 * Thread primitive for the link surface, matches the mixer fader's filament
 * look. kind "signal" renders three short vertical threads that light bottom-up
 * with the vermilion gradient and a bright flame cap; kind "battery" renders
 * one thin horizontal thread with a warm fill. level is 0..1.
 */
Item {
    id: root

    property real s: 1
    property string kind: "signal"
    property real level: 0

    implicitWidth: kind === "battery" ? 22 * s : 12 * s
    implicitHeight: kind === "battery" ? 3 * s : 14 * s

    Row {
        visible: root.kind === "signal"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        spacing: 3 * root.s

        Repeater {
            model: 3

            Item {
                id: bar
                required property int index
                readonly property bool lit: Math.round(root.level * 100) >= Math.round((index + 1) * 100 / 3)
                width: 2 * root.s
                height: 14 * root.s

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: (6 + 4 * bar.index) * root.s
                    radius: width / 2
                    color: PillTheme.threadBg

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: bar.lit
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: PillTheme.vermLit }
                            GradientStop { position: 1.0; color: PillTheme.vermBurn }
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 2.5 * root.s
                        radius: parent.radius
                        visible: bar.lit
                        color: PillTheme.flameCore
                    }
                }
            }
        }
    }

    Rectangle {
        visible: root.kind === "battery"
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 22 * root.s
        height: 3 * root.s
        radius: height / 2
        color: PillTheme.threadBg

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.level))
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: PillTheme.vermDim }
                GradientStop { position: 1.0; color: PillTheme.vermLit }
            }
        }
    }
}
