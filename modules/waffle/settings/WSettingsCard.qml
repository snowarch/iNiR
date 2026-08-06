pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root

    property string title: ""
    property string icon: ""
    property string description: ""
    property bool expanded: true
    property bool collapsible: false
    default property alias content: contentColumn.data

    readonly property int cardRadius: Looks.settings.radiusXLarge
    readonly property int cardPadding: Looks.settings.panelPadding
    readonly property color cardWash: Looks.settings.tile
    readonly property color cardStroke: Looks.settings.stroke

    Layout.fillWidth: true
    implicitHeight: mainColumn.implicitHeight

    Rectangle {
        id: surface
        z: 1
        anchors.fill: parent
        radius: root.cardRadius
        color: Looks.cookieEverywhere ? "transparent" : Looks.colors.bg1Base
        border.width: 0

        Loader {
            anchors.fill: parent
            active: Looks.cookieEverywhere && root.visible
            sourceComponent: CookieFace {
                role: "card"
                color: Looks.colors.bg1Base
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: !Looks.cookieEverywhere
            radius: parent.radius
            color: root.cardWash
            border.width: 1
            border.color: root.cardStroke
        }
    }

    ColumnLayout {
        id: mainColumn
        z: 2
        anchors {
            left: parent.left
            right: parent.right
        }
        spacing: 0

        // Header
        Item {
            visible: root.title !== ""
            Layout.fillWidth: true
            implicitHeight: Math.max(Looks.dp(48), headerRow.implicitHeight + root.cardPadding)

            Rectangle {
                id: headerBg
                anchors.fill: parent
                radius: root.expanded ? 0 : root.cardRadius
                // Top corners always rounded; bottom only when collapsed
                topLeftRadius: root.cardRadius
                topRightRadius: root.cardRadius
                color: root.collapsible && headerMa.containsMouse ? Looks.colors.bg1Hover : "transparent"

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }
            }

            MouseArea {
                id: headerMa
                anchors.fill: parent
                enabled: root.collapsible
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: root.collapsible
                onClicked: if (root.collapsible) root.expanded = !root.expanded
            }

            RowLayout {
                id: headerRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: root.cardPadding
                    rightMargin: root.cardPadding
                }
                spacing: Looks.dp(12)

                Rectangle {
                    visible: root.icon !== ""
                    implicitWidth: Looks.dp(28)
                    implicitHeight: Looks.dp(28)
                    radius: Looks.settings.radiusLarge
                    color: Looks.cookieEverywhere
                        ? "transparent" : Qt.alpha(Looks.colors.accent, 0.16)
                    Layout.alignment: root.description !== ""
                        ? Qt.AlignTop : Qt.AlignVCenter

                    CookieFace {
                        anchors.fill: parent
                        visible: Looks.cookieEverywhere
                        role: "badge"
                        selected: root.expanded
                        color: root.expanded ? Looks.colors.accent : Looks.colors.bg2
                    }

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: root.icon
                        implicitSize: Looks.dp(15)
                        color: Looks.cookieEverywhere
                            ? (root.expanded ? Looks.colors.accentFg : Looks.colors.fg)
                            : Looks.colors.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Looks.dp(3)

                    WText {
                        Layout.fillWidth: true
                        text: root.title
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.weight: Looks.font.weight.strong
                        color: Looks.colors.fg
                        elide: Text.ElideRight
                    }

                    WText {
                        visible: root.description !== ""
                        Layout.fillWidth: true
                        text: root.description
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }
                }

                FluentIcon {
                    visible: root.collapsible
                    icon: "chevron-up"
                    implicitSize: Looks.dp(12)
                    color: Looks.colors.subfg
                    Layout.alignment: root.description !== ""
                        ? Qt.AlignTop : Qt.AlignVCenter

                    rotation: root.expanded ? 0 : 180
                    Behavior on rotation {
                        animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }
                }
            }
        }

        // Content with smooth collapse
        Item {
            Layout.fillWidth: true
            implicitHeight: root.expanded ? contentColumn.implicitHeight + contentColumn.anchors.topMargin + contentColumn.anchors.bottomMargin : 0
            clip: true

            Behavior on implicitHeight {
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }

            ColumnLayout {
                id: contentColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    leftMargin: root.cardPadding
                    rightMargin: root.cardPadding
                    topMargin: root.title !== "" ? 0 : Looks.dp(10)
                    bottomMargin: Looks.dp(10)
                }
                spacing: 0
                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
