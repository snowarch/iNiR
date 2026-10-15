pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import org.kde.kirigami as Kirigami
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root
    focus: true

    required property var targetWindow
    signal confirm()
    signal cancel()

    readonly property string appId: String(targetWindow?.app_id ?? "")
    readonly property string appTitle: String(targetWindow?.title ?? "")
    readonly property string appDisplayName: appTitle || appId || Translation.tr("Unknown")
    readonly property bool showAppId: appId.length > 0
        && appId.toLowerCase() !== appDisplayName.toLowerCase()
    readonly property color dangerForeground: ColorUtils.ensureReadable(
        Looks.colors.fg, Looks.colors.danger, 4.5)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.cancel()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.confirm()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.4)
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            animation: NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    MascotImage {
        anchors.bottom: dialog.top
        anchors.bottomMargin: -12
        anchors.right: dialog.right
        anchors.rightMargin: Looks.dp(18)
        width: Looks.dp(92)
        height: Looks.dp(92)
        pose: "warning-concerned"
        surface: "dialogs"
    }

    WPane {
        id: dialog
        anchors.centerIn: parent
        radius: Looks.cookieEverywhere ? Looks.radius.xLarge : Looks.radius.large
        borderColor: Looks.glassActive ? Looks.colors.tooltipBorder : Looks.colors.bg2Border

        scale: 0.96
        opacity: 0
        Component.onCompleted: {
            scale = 1
            opacity = 1
        }
        Behavior on scale {
            animation: NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
        }
        Behavior on opacity {
            animation: NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
            }
        }

        contentItem: Item {
            implicitWidth: Looks.dp(360)
            implicitHeight: dialogColumn.implicitHeight
            width: implicitWidth
            height: implicitHeight

            ColumnLayout {
                id: dialogColumn
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    implicitHeight: contentColumn.implicitHeight + Looks.dp(32)

                    ColumnLayout {
                        id: contentColumn
                        anchors.fill: parent
                        anchors.margins: Looks.dp(16)
                        spacing: Looks.dp(10)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Looks.dp(12)

                            Rectangle {
                                Layout.preferredWidth: Looks.dp(48)
                                Layout.preferredHeight: Looks.dp(48)
                                Layout.alignment: Qt.AlignTop
                                radius: Looks.cookieEverywhere ? height / 2 : Looks.radius.large
                                color: Looks.colors.bg1
                                border.width: 1
                                border.color: Looks.colors.bg2Border

                                Kirigami.Icon {
                                    anchors.fill: parent
                                    anchors.margins: Looks.dp(8)
                                    source: root.appId
                                    fallback: "application-x-executable"
                                    roundToIconSize: false
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Looks.dp(3)

                                WText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Close this window?")
                                    font.pixelSize: Looks.font.pixelSize.xlarger
                                    font.weight: Looks.font.weight.strongest
                                    color: Looks.colors.fg
                                    wrapMode: Text.WordWrap
                                }

                                WText {
                                    Layout.fillWidth: true
                                    text: root.appDisplayName
                                    font.pixelSize: Looks.font.pixelSize.normal
                                    font.weight: Looks.font.weight.strong
                                    color: Looks.colors.fg
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                }

                                WText {
                                    Layout.fillWidth: true
                                    visible: root.showAppId
                                    text: root.appId
                                    font.pixelSize: Looks.font.pixelSize.small
                                    color: Looks.colors.subfg
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Looks.colors.bg0Border
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: actionRow.implicitHeight + Looks.dp(24)

                    RowLayout {
                        id: actionRow
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: Looks.dp(16)
                        spacing: Looks.dp(8)

                        WBorderedButton {
                            implicitWidth: Looks.dp(92)
                            implicitHeight: Looks.dp(34)
                            horizontalPadding: Looks.dp(14)
                            verticalPadding: Looks.dp(5)
                            text: Translation.tr("Cancel")
                            cookieMorphing: Looks.cookieEverywhere
                            onClicked: root.cancel()
                        }

                        WButton {
                            implicitWidth: Looks.dp(92)
                            implicitHeight: Looks.dp(34)
                            horizontalPadding: Looks.dp(14)
                            verticalPadding: Looks.dp(5)
                            text: Translation.tr("Close")
                            icon.name: "dismiss"
                            forceShowIcon: true
                            cookieMorphing: Looks.cookieEverywhere
                            colBackground: Looks.colors.danger
                            colBackgroundHover: Looks.colors.dangerActive
                            colBackgroundActive: Looks.colors.dangerActive
                            colForeground: root.dangerForeground
                            onClicked: root.confirm()
                        }
                    }
                }
            }
        }
    }
}
