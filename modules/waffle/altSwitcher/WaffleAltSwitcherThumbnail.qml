pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root

    required property var item
    property bool selected: false
    property int thumbnailWidth: 280
    property int thumbnailHeight: 180

    signal clicked

    implicitWidth: thumbnailWidth
    implicitHeight: thumbnailHeight + iconRow.height + 8

    // Selection border glow
    Rectangle {
        id: selectionGlow
        anchors.fill: thumbnailContainer
        anchors.margins: -4
        radius: Looks.radius.large + 4
        color: "transparent"
        border.width: root.selected ? 3 : 0
        border.color: Looks.colors.accent
        opacity: root.selected ? 1 : 0

        Behavior on opacity {
            animation: Looks.transition.opacity.createObject(this)
        }
        Behavior on border.width {
            animation: Looks.transition.resize.createObject(this)
        }
    }

    // Thumbnail container
    Rectangle {
        id: thumbnailContainer
        width: root.thumbnailWidth
        height: root.thumbnailHeight
        radius: Looks.radius.large
        color: Looks.colors.bg2Base
        clip: true

        // Hover/press states
        property bool isHovered: mouseArea.containsMouse
        property bool isPressed: mouseArea.pressed

        // Background with subtle gradient
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Looks.colors.bg2 }
                GradientStop { position: 1.0; color: Looks.colors.bg1Base }
            }
        }

        // Hover overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Looks.colors.bg2Hover
            opacity: thumbnailContainer.isHovered && !root.selected ? 0.5 : 0

            Behavior on opacity {
                animation: Looks.transition.opacity.createObject(this)
            }
        }

        // Large centered app icon (placeholder for actual window thumbnail)
        Image {
            id: appIcon
            anchors.centerIn: parent
            width: 96
            height: 96
            source: Quickshell.iconPath(
                AppSearch.guessIcon(root.item?.appId ?? root.item?.appName ?? ""),
                "application-x-executable"
            )
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        // Window title overlay at bottom
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 32
            radius: Looks.radius.large
            
            // Only round bottom corners
            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: parent.radius
                color: parent.color
            }
            
            color: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.2)

            WText {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: root.item?.title ?? ""
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.fg
                elide: Text.ElideRight
            }
        }

        // Scale animation on press
        scale: thumbnailContainer.isPressed ? 0.96 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
    }

    // App icon + workspace indicator row below thumbnail
    Row {
        id: iconRow
        anchors.top: thumbnailContainer.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        // Small app icon
        Image {
            width: 18
            height: 18
            source: Quickshell.iconPath(
                AppSearch.guessIcon(root.item?.appId ?? root.item?.appName ?? ""),
                "application-x-executable"
            )
            sourceSize: Qt.size(18, 18)
        }

        // Workspace indicator
        Rectangle {
            visible: (root.item?.workspaceIdx ?? 0) > 0
            width: wsLabel.implicitWidth + 8
            height: 18
            radius: Looks.radius.small
            color: root.selected ? Looks.colors.accent : Looks.colors.bg1

            WText {
                id: wsLabel
                anchors.centerIn: parent
                text: Translation.tr("WS") + " " + (root.item?.workspaceIdx ?? "")
                font.pixelSize: Looks.font.pixelSize.small
                color: root.selected ? Looks.colors.accentFg : Looks.colors.subfg
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
