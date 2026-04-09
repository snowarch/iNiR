import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentPage {
    settingsPageIndex: 13
    settingsPageName: Translation.tr("About")

    SettingsCardSection {
        expanded: true
        icon: "computer"
        title: Translation.tr("System")

        SettingsGroup {
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                Layout.topMargin: 10
                Layout.bottomMargin: 10

                Item {
                    width: 64
                    height: 64

                    Image {
                        id: distroIconImage

                        anchors.fill: parent
                        sourceSize.width: 64
                        sourceSize.height: 64
                        source: Quickshell.shellPath(`assets/icons/${SystemInfo.distroIcon}.svg`)
                        fillMode: Image.PreserveAspectFit
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: distroIconImage
                        source: distroIconImage
                        colorization: 1
                        colorizationColor: Appearance.m3colors.m3primary
                        visible: distroIconImage.status === Image.Ready
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: distroIconImage.status !== Image.Ready
                        text: "computer"
                        iconSize: 64
                        color: Appearance.m3colors.m3primary
                    }

                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter

                    StyledText {
                        text: SystemInfo.distroName || "Linux"
                        font.pixelSize: Appearance.font.pixelSize.title
                    }

                    StyledText {
                        visible: SystemInfo.homeUrl && SystemInfo.homeUrl.length > 0
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        text: SystemInfo.homeUrl ? `[${SystemInfo.homeUrl}](${SystemInfo.homeUrl})` : ""
                        textFormat: Text.MarkdownText
                        onLinkActivated: (link) => {
                            return Qt.openUrlExternally(link);
                        }

                        PointingHandLinkHover {
                        }

                    }

                }

            }

            Flow {
                Layout.fillWidth: true
                spacing: 5

                RippleButtonWithIcon {
                    visible: SystemInfo.documentationUrl && SystemInfo.documentationUrl.length > 0
                    materialIcon: "auto_stories"
                    mainText: Translation.tr("Documentation")
                    onClicked: Qt.openUrlExternally(SystemInfo.documentationUrl)
                }

                RippleButtonWithIcon {
                    visible: SystemInfo.supportUrl && SystemInfo.supportUrl.length > 0
                    materialIcon: "support"
                    mainText: Translation.tr("Help & Support")
                    onClicked: Qt.openUrlExternally(SystemInfo.supportUrl)
                }

                RippleButtonWithIcon {
                    visible: SystemInfo.bugReportUrl && SystemInfo.bugReportUrl.length > 0
                    materialIcon: "bug_report"
                    mainText: Translation.tr("Report a Bug")
                    onClicked: Qt.openUrlExternally(SystemInfo.bugReportUrl)
                }

            }

        }

    }

    SettingsCardSection {
        expanded: false
        icon: "deployed_code"
        title: "iNiR"

        SettingsGroup {
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                Layout.topMargin: 10
                Layout.bottomMargin: 10

                // Round icon container
                Rectangle {
                    width: 68
                    height: 68
                    radius: 34
                    color: "transparent"
                    border.width: 2
                    border.color: Appearance.m3colors.m3primary

                    Image {
                        id: projectIcon

                        anchors.centerIn: parent
                        width: 60
                        height: 60
                        sourceSize.width: 60
                        sourceSize.height: 60
                        source: Quickshell.shellPath("assets/icons/sf.svg")
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: Appearance.effectsEnabled

                        layer.effect: MultiEffect {
                            maskEnabled: true

                            maskSource: ShaderEffectSource {

                                sourceItem: Rectangle {
                                    width: 60
                                    height: 60
                                    radius: 30
                                }

                            }

                        }

                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: projectIcon.status !== Image.Ready
                        text: "deployed_code"
                        iconSize: 48
                        color: Appearance.m3colors.m3primary
                    }

                    // Avatar interaction feedback
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: _avatarFx.restart()
                    }

                    Text {
                        id: _avatarFxLabel
                        text: "\ud83e\udec3\ud83c\udffb"
                        font.pixelSize: 36
                        anchors.centerIn: parent
                        visible: false
                        z: 10

                        SequentialAnimation {
                            id: _avatarFx
                            PropertyAction { target: _avatarFxLabel; property: "visible"; value: true }
                            PropertyAction { target: _avatarFxLabel; property: "scale"; value: 0 }
                            PropertyAction { target: _avatarFxLabel; property: "opacity"; value: 1 }
                            NumberAnimation { target: _avatarFxLabel; property: "scale"; to: 1.5; duration: 300; easing.type: Easing.OutBack }
                            NumberAnimation { target: _avatarFxLabel; property: "scale"; to: 1.0; duration: 200 }
                            PauseAnimation { duration: 800 }
                            ParallelAnimation {
                                NumberAnimation { target: _avatarFxLabel; property: "opacity"; to: 0; duration: 400 }
                                NumberAnimation { target: _avatarFxLabel; property: "scale"; to: 2.0; duration: 400 }
                            }
                            PropertyAction { target: _avatarFxLabel; property: "visible"; value: false }
                        }
                    }

                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter

                    StyledText {
                        text: "iNiR"
                        font.pixelSize: Appearance.font.pixelSize.title
                    }

                    StyledText {
                        text: "[https://github.com/snowarch/inir](https://github.com/snowarch/inir)"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        textFormat: Text.MarkdownText
                        onLinkActivated: (link) => {
                            return Qt.openUrlExternally(link);
                        }

                        PointingHandLinkHover {
                        }

                    }

                }

            }

            Flow {
                Layout.fillWidth: true
                spacing: 5

                RippleButtonWithIcon {
                    materialIcon: "auto_stories"
                    mainText: Translation.tr("Documentation")
                    onClicked: Qt.openUrlExternally("https://snowarch.github.io/iNiR/docs/")
                }

                RippleButtonWithIcon {
                    materialIcon: "bug_report"
                    mainText: Translation.tr("Issues")
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/issues")
                }

            }

        }

    }

    SettingsCardSection {
        expanded: false
        icon: "favorite"
        title: Translation.tr("Based on")

        SettingsGroup {
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                Layout.topMargin: 10
                Layout.bottomMargin: 10

                Item {
                    width: 64
                    height: 64

                    Image {
                        id: end4Icon

                        anchors.fill: parent
                        sourceSize.width: 64
                        sourceSize.height: 64
                        source: Quickshell.shellPath("assets/icons/illogical-impulse.svg")
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: end4Icon.status !== Image.Ready
                        text: "favorite"
                        iconSize: 64
                        color: Appearance.m3colors.m3primary
                    }

                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter

                    StyledText {
                        text: "illogical-impulse"
                        font.pixelSize: Appearance.font.pixelSize.title
                    }

                    StyledText {
                        text: "[https://github.com/end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        textFormat: Text.MarkdownText
                        onLinkActivated: (link) => {
                            return Qt.openUrlExternally(link);
                        }

                        PointingHandLinkHover {
                        }

                    }

                }

            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("This project is a fork of end-4's illogical-impulse, adapted for the Niri compositor.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 5

                RippleButtonWithIcon {
                    materialIcon: "open_in_new"
                    mainText: "illogical-impulse"
                    onClicked: Qt.openUrlExternally("https://github.com/end-4/dots-hyprland")
                }

                RippleButtonWithIcon {
                    materialIcon: "volunteer_activism"
                    mainText: Translation.tr("Support end-4")
                    onClicked: Qt.openUrlExternally("https://github.com/sponsors/end-4")
                }

            }

        }

    }

}
