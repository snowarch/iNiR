import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    default property alias contentData: content.data

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + SettingsMaterialPreset.groupPadding * 2

    radius: SettingsMaterialPreset.groupRadius
    color: SettingsMaterialPreset.groupColor
    border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
        : Appearance.zzzEverywhere ? 0 : 0
    border.color: SettingsMaterialPreset.groupBorderColor

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

    // No accent rail here — SettingsGroup lives inside SettingsCardSection
    // which already has the left accent rail. A second rail here would double.

    ColumnLayout {
        id: content
        anchors {
            fill: parent
            margins: SettingsMaterialPreset.groupPadding
        }
        spacing: SettingsMaterialPreset.groupSpacing
    }
}
