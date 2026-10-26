import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.services
import qs.modules.waffle.looks

// Waffle's part `familyTransition`: what the family switch overlay (FamilyTransitionOverlay.qml) shows on the way in.
Item {
    id: waffleRoot
    required property var overlay
    // Frozen when the switch starts, so the palette moving underneath never flickers the card.
    property color snapBg0: "transparent"
    property color snapBg1: "transparent"
    property color snapFg: "transparent"
    property color snapSubfg: "transparent"
    property color snapAccent: "transparent"
    readonly property color plate: waffleRoot.snapBg0
    readonly property real tint: 0.08
    // Waffle may wear its own wallpaper.
    readonly property string wallpaperPath: {
        const wBg = Config.options?.waffles?.background ?? {}
        const main = Config.options?.background?.wallpaperPath ?? ""
        return (wBg.useMainWallpaper ?? true) ? main : (wBg.wallpaperPath ?? main)
    }
    anchors.fill: parent

    property bool expanded: false
    property bool showIcon: false
    property bool showText: false
    property bool showAccent: false

    Component.onCompleted: {
        waffleRoot.snapBg0 = Looks.colors.bg0
        waffleRoot.snapBg1 = Looks.colors.bg1
        waffleRoot.snapFg = Looks.colors.fg
        waffleRoot.snapSubfg = Looks.colors.subfg
        waffleRoot.snapAccent = Looks.colors.accent
        Qt.callLater(() => expanded = true)
    }

    // Staggered content reveal
    Timer { interval: 160; running: waffleRoot.expanded; onTriggered: waffleRoot.showIcon = true }
    Timer { interval: 240; running: waffleRoot.expanded; onTriggered: waffleRoot.showText = true }
    Timer { interval: 320; running: waffleRoot.expanded; onTriggered: waffleRoot.showAccent = true }

    // ── Acrylic card ──
    Rectangle {
        id: acrylicCard
        anchors.centerIn: parent
        width: 260
        height: 180
        radius: Looks.radius.xLarge
        color: ColorUtils.transparentize(waffleRoot.snapBg1, 0.15)
        border.width: 1
        border.color: ColorUtils.transparentize(waffleRoot.snapFg, 0.9)

        opacity: overlay._phase ? 0 : (waffleRoot.expanded ? 1 : 0)
        scale: overlay._phase ? 0.92 : (waffleRoot.expanded ? 1 : 0.82)

        Behavior on opacity {
            NumberAnimation {
                duration: overlay._phase ? 200 : 280
                easing.type: Easing.BezierSpline
                easing.bezierCurve: overlay._phase
                    ? Looks.transition.easing.bezierCurve.accelerate
                    : Looks.transition.easing.bezierCurve.decelerate
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: overlay._phase ? 220 : 340
                easing.type: Easing.BezierSpline
                easing.bezierCurve: overlay._phase
                    ? Looks.transition.easing.bezierCurve.accelerate
                    : Looks.transition.easing.bezierCurve.decelerate
            }
        }

        // Accent shimmer line
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: waffleRoot.showAccent && !overlay._phase ? 48 : 0
            height: 2.5
            radius: 1.25
            color: waffleRoot.snapAccent
            opacity: overlay._phase ? 0 : 1

            Behavior on width {
                NumberAnimation {
                    duration: overlay._phase ? 120 : 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                }
            }
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    // ── Icon ──
    Image {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -22
        width: 48
        height: 48
        source: `${Looks.iconsPath}/start-here.svg`
        sourceSize: Qt.size(48, 48)
        opacity: overlay._phase ? 0 : (waffleRoot.showIcon ? 1 : 0)
        scale: overlay._phase ? 0.9 : (waffleRoot.showIcon ? 1 : 0.7)

        Behavior on opacity {
            NumberAnimation {
                duration: overlay._phase ? 120 : 240
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: overlay._phase ? 140 : 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
        }

        layer.enabled: Appearance.effectsEnabled
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: waffleRoot.snapFg
        }
    }

    // ── Text group ──
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 32
        spacing: 3
        opacity: overlay._phase ? 0 : (waffleRoot.showText ? 1 : 0)
        scale: overlay._phase ? 0.95 : (waffleRoot.showText ? 1 : 0.92)

        Behavior on opacity {
            NumberAnimation {
                duration: overlay._phase ? 100 : 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: overlay._phase ? 120 : 260
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Waffle"
            font.pixelSize: 19
            font.family: Looks.font.family.ui
            font.weight: Font.DemiBold
            color: waffleRoot.snapFg
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Windows 11 Style"
            font.pixelSize: Looks.font.pixelSize.small
            font.family: Looks.font.family.ui
            color: waffleRoot.snapSubfg
        }
    }
}
