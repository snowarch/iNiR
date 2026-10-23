pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// One empty / offline / error block for Material widgets: a tonal mark, what is true now, and the one thing to do.
// Small keeps the mark and the title; the detail and the action come back when there is room.
Item {
    id: root

    required property var widget
    property string icon: "check"
    property string title: ""
    property string detail: ""
    property string actionLabel: ""
    property string actionIcon: "refresh"
    property bool busy: false
    signal action()

    readonly property real s: root.widget.scaleFactor
    readonly property bool roomy: root.height >= 120 * root.s && root.width >= 150 * root.s
    readonly property color face: root.widget.widgetSemanticContainer(root.widget.widgetPrimaryRole)
    readonly property color mark: root.widget.widgetSemanticOnContainer(root.widget.widgetPrimaryRole)

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Math.round(24 * root.s), Math.round(300 * root.s))
        spacing: Math.round(6 * root.s)

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Math.round(4 * root.s)
            implicitWidth: Math.round((root.roomy ? 44 : 36) * root.s)
            implicitHeight: implicitWidth
            radius: width / 2
            color: root.face
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.icon
                fill: 1
                iconSize: Math.round((root.roomy ? 22 : 18) * root.s)
                color: root.mark
            }
        }
        StyledText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.title
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: root.widget.widgetInk
            font.family: root.widget.widgetTitleFamily
            font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.s)
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.fillWidth: true
            visible: root.roomy && text.length > 0
            text: root.detail
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: root.widget.widgetInkMuted
            font.family: root.widget.widgetBodyFamily
            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.s)
        }
        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(4 * root.s)
            visible: root.actionLabel.length > 0
            enabled: !root.busy
            implicitHeight: Math.round(32 * root.s)
            implicitWidth: actionRow.implicitWidth + Math.round(28 * root.s)
            buttonRadius: Appearance.rounding.full
            colBackground: root.face
            colBackgroundHover: ColorUtils.mix(root.face, root.mark, 0.86)
            colRipple: ColorUtils.applyAlpha(root.mark, 0.16)
            releaseAction: () => root.action()
            contentItem: Item {
                RowLayout {
                    id: actionRow
                    anchors.centerIn: parent
                    spacing: Math.round(6 * root.s)
                    MaterialSymbol {
                        text: root.actionIcon
                        iconSize: Math.round(16 * root.s)
                        color: root.mark
                        RotationAnimation on rotation {
                            running: root.busy && root.widget.animationsActive
                            from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        }
                    }
                    StyledText {
                        text: root.actionLabel
                        color: root.mark
                        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.s)
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
