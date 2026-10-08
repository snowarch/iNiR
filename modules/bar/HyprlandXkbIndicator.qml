import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Loader {
    id: root
    property bool vertical: false
    property color color: Appearance.colors.colOnSurfaceVariant
    active: KeyboardIndicators.hasPanelIndicators
    visible: active
    Layout.preferredWidth: active && item ? item.implicitWidth : 0
    Layout.preferredHeight: active && item ? item.implicitHeight : 0

    sourceComponent: Item {
        implicitWidth: root.vertical ? indicatorColumn.implicitWidth : indicatorRow.implicitWidth
        implicitHeight: root.vertical ? indicatorColumn.implicitHeight : indicatorRow.implicitHeight

        Row {
            id: indicatorRow
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: Appearance.sizes.spacingSmall

            MaterialSymbol {
                opacity: KeyboardIndicators.capsLockVisible ? 1 : 0
                visible: opacity > 0
                text: KeyboardIndicators.capsMaterialIcon
                iconSize: Appearance.font.pixelSize.large
                fill: 1
                color: root.color
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            MaterialSymbol {
                opacity: KeyboardIndicators.numLockVisible ? 1 : 0
                visible: opacity > 0
                text: KeyboardIndicators.numMaterialIcon
                iconSize: Appearance.font.pixelSize.large
                fill: 1
                color: root.color
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            StyledText {
                opacity: KeyboardIndicators.layoutVisible ? 1 : 0
                visible: opacity > 0
                horizontalAlignment: Text.AlignHCenter
                text: KeyboardIndicators.currentLayoutCodeInline
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.color
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }

        Column {
            id: indicatorColumn
            visible: root.vertical
            anchors.centerIn: parent
            spacing: Appearance.sizes.spacingSmall / 2

            MaterialSymbol {
                opacity: KeyboardIndicators.capsLockVisible ? 1 : 0
                visible: opacity > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: KeyboardIndicators.capsMaterialIcon
                iconSize: Appearance.font.pixelSize.large
                fill: 1
                color: root.color
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            MaterialSymbol {
                opacity: KeyboardIndicators.numLockVisible ? 1 : 0
                visible: opacity > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: KeyboardIndicators.numMaterialIcon
                iconSize: Appearance.font.pixelSize.large
                fill: 1
                color: root.color
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            StyledText {
                opacity: KeyboardIndicators.layoutVisible ? 1 : 0
                visible: opacity > 0
                horizontalAlignment: Text.AlignHCenter
                text: KeyboardIndicators.currentLayoutCodeMultiline
                font.pixelSize: text.includes("\n") ? Appearance.font.pixelSize.smallie : Appearance.font.pixelSize.smaller
                color: root.color
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }
    }
}
