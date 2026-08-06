pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

TextField {
    id: filterField

    property alias colBackground: background.color

    Layout.fillHeight: true
    implicitWidth: 200
    implicitHeight: Math.max(Appearance.sizes.baseBarHeight, contentHeight + Math.round(12 * Appearance.fontSizeScale))
    leftPadding: 10
    rightPadding: 10
    topPadding: 0
    bottomPadding: 0
    verticalAlignment: TextInput.AlignVCenter

    placeholderTextColor: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
    color: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer1
    font {
        family: Appearance.font.family.main
        pixelSize: Appearance.font.pixelSize.small
        hintingPreference: Font.PreferFullHinting
        variableAxes: Appearance.font.variableAxes.main
    }
    renderType: Text.NativeRendering
    selectedTextColor: Appearance.zzzEverywhere ? Appearance.zzz.onSignal : Appearance.colors.colOnSecondaryContainer
    selectionColor: Appearance.zzzEverywhere ? Appearance.zzz.signal : Appearance.colors.colSecondaryContainer

    background: Rectangle {
        id: background
        color: Appearance.zzzEverywhere ? Appearance.zzz.paper : Appearance.colors.colLayer1
        radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.full
        border.width: Appearance.zzzEverywhere ? 1 : 0
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong : "transparent"
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
        Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    }

    TextInputContextMenu {
        target: filterField
    }
}
