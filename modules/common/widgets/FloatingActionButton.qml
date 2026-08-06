pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Material 3 FAB.
 */
RippleButton {
    id: root
    property string iconText: "add"
    property bool expanded: false
    property real baseSize: 56
    property real elementSpacing: 5
    implicitWidth: expanded ? (Math.max(contentRowLayout.implicitWidth + 10 * 2, baseSize)) : baseSize
    implicitHeight: baseSize

    Behavior on implicitWidth {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }

    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal : (baseSize / 14 * 4)
    colBackground: Appearance.zzzEverywhere ? Appearance.zzz.sticker
                 : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                 : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
                 : Appearance.colors.colPrimaryContainer
    colBackgroundHover: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover
                      : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                      : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
                      : Appearance.colors.colPrimaryContainerHover
    colRipple: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive
             : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
             : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerActive
             : Appearance.colors.colPrimaryContainerActive
    property color colOnBackground: Appearance.zzzEverywhere ? Appearance.zzz.onSticker
                                  : Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                  : Appearance.inirEverywhere ? Appearance.inir.colOnPrimaryContainer
                                  : Appearance.colors.colOnPrimaryContainer
    contentItem: Row {
        id: contentRowLayout
        property real horizontalMargins: (root.baseSize - icon.width) / 2
        anchors {
            verticalCenter: parent?.verticalCenter
            left: parent?.left
            leftMargin: contentRowLayout.horizontalMargins
        }
        spacing: 0

        MaterialSymbol {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            iconSize: 26
            color: root.colOnBackground
            text: root.iconText
        }
        Loader {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.buttonText?.length > 0
            active: true
            sourceComponent: Revealer {
                visible: root.expanded || implicitWidth > 0
                reveal: root.expanded
                width: reveal ? (buttonText.implicitWidth + root.elementSpacing + contentRowLayout.horizontalMargins) : 0
                StyledText {
                    id: buttonText
                    anchors {
                        left: parent.left
                        leftMargin: root.elementSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.buttonText
                    color: root.colOnBackground
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: 450
                }
            }
        }
    }
}
