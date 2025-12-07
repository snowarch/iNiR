import QtQuick
import QtQuick.Layouts
import Quickshell
import org.kde.kirigami as Kirigami
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

Item {
    id: root
    focus: true

    required property var targetWindow
    signal confirm()
    signal cancel()

    readonly property string appId: targetWindow?.app_id ?? ""
    readonly property string appTitle: targetWindow?.title ?? ""

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.cancel()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.confirm()
            event.accepted = true
        }
    }

    // Scrim
    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.4)
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            animation: Looks.transition.opacity.createObject(this)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    // Dialog - Windows 11 ContentDialog style
    WPane {
        id: dialog
        anchors.centerIn: parent
        radius: Looks.radius.large

        scale: 0.96
        opacity: 0
        Component.onCompleted: { scale = 1; opacity = 1 }
        Behavior on scale {
            animation: Looks.transition.enter.createObject(this)
        }
        Behavior on opacity {
            animation: Looks.transition.opacity.createObject(this)
        }

        contentItem: ColumnLayout {
            spacing: 0

            // Content area
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 24
                Layout.bottomMargin: 20
                spacing: 16

                // App icon
                Kirigami.Icon {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignTop
                    source: root.appId
                    fallback: "application-x-executable"
                    roundToIconSize: false
                }

                // Text content
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Title
                    WText {
                        Layout.fillWidth: true
                        text: Translation.tr("Close this window?")
                        font {
                            pixelSize: Looks.font.pixelSize.larger
                            weight: Looks.font.weight.strong
                        }
                        wrapMode: Text.Wrap
                    }

                    // App title
                    WText {
                        Layout.fillWidth: true
                        text: root.appTitle || root.appId || Translation.tr("Unknown")
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.fg
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }

                    // App ID (if different from title)
                    WText {
                        Layout.fillWidth: true
                        text: root.appId
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                        visible: root.appId !== "" && root.appId !== root.appTitle
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Looks.colors.bg0Border
            }

            // Button area - centered, Cancel left, Close right
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: buttonsRow.height + 32
                
                RowLayout {
                    id: buttonsRow
                    anchors.centerIn: parent
                    spacing: 8

                    // Cancel button (safe action)
                    WBorderedButton {
                        implicitWidth: 90
                        implicitHeight: 30
                        horizontalPadding: 16
                        verticalPadding: 4
                        text: Translation.tr("Cancel")
                        
                        font {
                            pixelSize: Looks.font.pixelSize.normal
                            weight: Looks.font.weight.regular
                        }

                        onClicked: root.cancel()
                    }

                    // Close button (primary action)
                    WBorderedButton {
                        implicitWidth: 90
                        implicitHeight: 30
                        horizontalPadding: 16
                        verticalPadding: 4
                        text: Translation.tr("Close")
                        
                        colBackground: Looks.colors.accent
                        colBackgroundHover: Looks.colors.accentHover
                        colBackgroundActive: Looks.colors.accentActive
                        colBorder: Looks.colors.accent
                        colForeground: Looks.colors.accentFg
                        
                        font {
                            pixelSize: Looks.font.pixelSize.normal
                            weight: Looks.font.weight.regular
                        }

                        onClicked: root.confirm()
                    }
                }
            }
        }
    }
}
