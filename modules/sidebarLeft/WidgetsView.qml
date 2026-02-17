pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarLeft.widgets
import qs.services
import "root:"

Item {
    id: root

    readonly property bool editMode: widgetContainer.editMode
    readonly property bool dragPending: widgetContainer.dragPending
    property bool animateIn: GlobalStates.sidebarLeftOpen

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (GlobalStates.sidebarLeftOpen) {
                root.animateIn = false
                animateInTimer.restart()
            } else {
                root.animateIn = false
            }
        }
    }

    Timer {
        id: animateInTimer
        interval: 50
        onTriggered: root.animateIn = true
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.bottomMargin: editHint.visible ? editHint.height + 12 : 0
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.editMode && !root.dragPending

        Behavior on anchors.bottomMargin {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: mainColumn
            width: flickable.width
            spacing: 0

            GlanceHeader {
                id: glanceHeader
                Layout.fillWidth: true
                Layout.bottomMargin: 16

                opacity: root.animateIn ? 1 : 0
                scale: root.animateIn ? 1 : 0.97
                transformOrigin: Item.Top
                transform: Translate { y: root.animateIn ? 0 : 18 }

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: 450
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                }
                Behavior on transform {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: 450
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }
            }

            DraggableWidgetContainer {
                id: widgetContainer
                Layout.fillWidth: true
                animateIn: root.animateIn
            }

            Item { Layout.preferredHeight: 12 }
        }
    }

    // Edit mode hint
    Rectangle {
        id: editHint
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        width: hintContent.implicitWidth + 24
        height: 32
        radius: 16
        color: Appearance.colors.colPrimary
        opacity: root.editMode ? 1 : 0
        visible: opacity > 0
        scale: root.editMode ? 1 : 0.9

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Row {
            id: hintContent
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: "swap_vert"
                iconSize: 16
                color: Appearance.colors.colOnPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: Translation.tr("Drag to reorder • release to drop")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colOnPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
