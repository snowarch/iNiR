pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// ZzzCard — the calm unified ZZZ content surface.
//
// ONE hairline border (no panel+card+group stacking), a generated fill ramp
// driven by `elevation`, and a radius that respects the square/round shape
// axis. Built as a native Rectangle so it obeys
// `radius` correctly in BOTH square (small manufactured radius) and round
// (softer anime) modes — the failure mode this replaces is the old Shape-
// based plate that ignored radius and stayed sharp in round mode.
//
// Drop content into the default slot; it sits on top of the plate. Use this
// for settings cards, sidebar cards, control-panel sections, dashboard cards,
// overview tiles — anywhere you want a ZZZ plate without a heavy double border.
//
// Zero work when ZZZ is inactive: the whole surface collapses to transparent
// (ComponentBehavior: Bound; no delegates created).
Item {
    id: root

    default property alias content: contentHolder.data

    // Fill ramp: 0 = tile (resting plate), 1 = paperAlt (raised), 2 = chrome
    // (sunken panel). Reads as a depth ladder WITHOUT stacking borders.
    property int elevation: 0
    property bool showBorder: true
    property color fillColor: elevation === 0 ? Appearance.zzz.tile
                          : elevation === 1 ? Appearance.zzz.paperAlt
                          : Appearance.zzz.chrome
    property color borderColor: Appearance.zzz.hairline
    property real radius: Appearance.zzz.cardRadius

    readonly property bool active: Appearance.zzzEverywhere

    implicitHeight: 0
    implicitWidth: 0

    Rectangle {
        id: plate
        anchors.fill: parent
        visible: root.active
        radius: root.radius
        color: root.active ? root.fillColor : "transparent"
        border.width: root.active && root.showBorder ? Appearance.zzz.hairlineThick : 0
        border.color: root.borderColor

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        // zzzOvershoot curve so a square↔round shape flip feels mechanical.
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot }
        }
    }

    Item {
        id: contentHolder
        anchors.fill: parent
    }
}
