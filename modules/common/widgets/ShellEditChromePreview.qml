pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions

Item {
    id: root

    required property string familyLabel
    required property string previewIcon
    required property color accentColor
    required property color surfaceColor
    required property color textColor
    required property color secondaryTextColor
    required property real radius
    required property string iconFontFamily
    required property string textFontFamily
    required property int titlePixelSize
    required property int detailPixelSize
    required property int animationDuration

    implicitWidth: 680
    implicitHeight: 360

    Component.onCompleted: console.info("[ShellEditChromePreview] ready:", root.familyLabel)

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: ColorUtils.applyAlpha(root.surfaceColor, 0.98)
        border.width: 1
        border.color: ColorUtils.applyAlpha(root.accentColor, 0.36)
    }

    Text {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 18
        }
        text: root.familyLabel
        color: root.textColor
        font.family: root.textFontFamily
        font.pixelSize: root.titlePixelSize + 2
        font.weight: Font.DemiBold
    }

    ShellEditHudContext {
        anchors {
            top: parent.top
            left: parent.left
            topMargin: 54
            leftMargin: 24
        }
        width: implicitWidth
        height: implicitHeight
        icon: root.previewIcon
        title: qsTr("Selected surface")
        detail: qsTr("Output · scope · operation")
        accentColor: root.accentColor
        backgroundColor: root.surfaceColor
        textColor: root.textColor
        secondaryTextColor: root.secondaryTextColor
        radius: root.radius
        iconFontFamily: root.iconFontFamily
        textFontFamily: root.textFontFamily
        titlePixelSize: root.titlePixelSize
        detailPixelSize: root.detailPixelSize
    }

    Row {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 112
        }
        spacing: 14

        ShellEditDropTarget {
            width: 180
            height: 58
            slot: "valid"
            label: qsTr("Available")
            active: true
            valid: true
            occupied: false
            previewed: true
            accentColor: root.accentColor
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            radius: root.radius
            fontFamily: root.textFontFamily
            fontPixelSize: root.titlePixelSize
            animationDuration: root.animationDuration
        }

        ShellEditDropTarget {
            width: 180
            height: 58
            slot: "occupied"
            label: qsTr("Occupied")
            active: true
            valid: true
            occupied: true
            previewed: false
            accentColor: root.accentColor
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            radius: root.radius
            fontFamily: root.textFontFamily
            fontPixelSize: root.titlePixelSize
            animationDuration: root.animationDuration
        }

        ShellEditDropTarget {
            width: 180
            height: 58
            slot: "invalid"
            label: qsTr("Unavailable")
            active: true
            valid: false
            occupied: false
            previewed: false
            accentColor: root.accentColor
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            radius: root.radius
            fontFamily: root.textFontFamily
            fontPixelSize: root.titlePixelSize
            animationDuration: root.animationDuration
        }
    }

    Item {
        id: framedSurface
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 42
            rightMargin: 42
            bottomMargin: 30
        }
        height: 120

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: ColorUtils.applyAlpha(root.surfaceColor, 0.72)
        }

        ShellEditSurfaceFrame {
            anchors.fill: parent
            surfaceId: "diagnostic"
            label: qsTr("Selected frame")
            active: true
            selected: true
            accentColor: root.accentColor
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            frameRadius: root.radius
            fontFamily: root.textFontFamily
            fontPixelSize: root.titlePixelSize
            animationDuration: root.animationDuration
        }

        ShellEditResizeHandle {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: -8
            }
            width: 20
            height: 72
            axis: "horizontal"
            active: true
            accentColor: root.accentColor
            surfaceColor: root.surfaceColor
            radius: root.radius
        }
    }
}
