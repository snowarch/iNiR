import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Flickable {
    readonly property var root: WelcomeHost.wizard
    id: welcomeFlickable
    width: root.stepWidth
    contentHeight: welcomeColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    bottomMargin: 18
    topMargin: Math.max(root.compact ? 8 : 14,
        Math.min(root.compact ? 20 : 28,
            Math.round((height - welcomeColumn.implicitHeight - bottomMargin) / 2)))

    ColumnLayout {
        id: welcomeColumn
        width: parent.width
        spacing: root.compact ? 14 : 18

        GridLayout {
            Layout.fillWidth: true
            columns: welcomeFlickable.width < 720 ? 1 : 2
            columnSpacing: root.compact ? 22 : 34
            rowSpacing: 18

            ColumnLayout {
                visible: !root.familyWelcome?.intro || welcomeFlickable.width >= 720
                Layout.fillWidth: true
                Layout.preferredWidth: welcomeFlickable.width < 720
                    ? welcomeFlickable.width : (welcomeFlickable.width - (root.compact ? 22 : 34)) * root.welcomeIntroShare
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: root.compact ? 2 : 6
                spacing: 10

                Loader {
                    Layout.fillWidth: true
                    active: !!root.familyWelcome?.intro
                    visible: active
                    sourceComponent: root.familyWelcome?.intro ?? null
                }

                RowLayout {
                    visible: !root.familyWelcome?.intro
                    Layout.fillWidth: true
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        InirMark {
                            implicitSize: root.compact ? 34 : 40
                            Layout.bottomMargin: 4
                            ink: root.welcomeOnSurface
                            accent: root.welcomeAccent
                        }

                        WelcomeText {
                            Layout.fillWidth: true
                            text: "iNiR"
                            font.family: root.welcomeFontExpressive
                            font.pixelSize: root.compact ? 42 : 54
                            font.weight: Font.Bold
                            font.letterSpacing: -0.7
                            color: root.welcomeOnSurface
                        }

                        WelcomeText {
                            Layout.fillWidth: true
                            text: Translation.tr("A complete Niri shell with sensible defaults and room to make it yours.")
                            font.pixelSize: root.welcomeFontBody
                            font.weight: Font.Medium
                            color: root.welcomeSecondaryText
                            wrapMode: Text.WordWrap
                        }
                    }

                    MascotImage {
                        id: welcomeMascot
                        previewMode: true
                        pose: "welcome-wave"
                        visible: status === Image.Ready && welcomeFlickable.width >= 720
                        Layout.preferredWidth: visible ? (root.compact ? 142 : 176) : 0
                        Layout.preferredHeight: visible ? (root.compact ? 176 : 214) : 0
                        Layout.alignment: Qt.AlignBottom
                    }

                    Item {
                        visible: welcomeMascot.status !== Image.Ready && welcomeFlickable.width >= 720
                        Layout.preferredWidth: visible ? (root.compact ? 132 : 166) : 0
                        Layout.preferredHeight: visible ? (root.compact ? 162 : 194) : 0
                        Layout.alignment: Qt.AlignBottom

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "deployed_code"
                            iconSize: root.compact ? 42 : 50
                            color: root.welcomeAccent
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !root.familyWelcome?.intro
                    Layout.topMargin: root.compact ? 8 : 16
                    spacing: 12
                    Repeater {
                        model: [
                            { icon: "palette", label: Translation.tr("Appearance"), detail: Translation.tr("Style, theme and wallpaper") },
                            { icon: "dashboard", label: Translation.tr("Desktop"), detail: Translation.tr("Family, bar and dock placement") },
                            { icon: "tune", label: Translation.tr("Essentials"), detail: Translation.tr("Effects and useful defaults") }
                        ]
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialSymbol {
                                Layout.preferredWidth: 24
                                text: modelData.icon
                                iconSize: 18
                                color: root.welcomeAccent
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                WelcomeText {
                                    text: modelData.label
                                    font.pixelSize: root.welcomeFontBody
                                    font.weight: Font.DemiBold
                                    color: root.welcomeOnSurface
                                }
                                WelcomeText {
                                    Layout.fillWidth: true
                                    text: modelData.detail
                                    font.pixelSize: root.welcomeFontCaption
                                    color: root.welcomeSecondaryText
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: welcomeFlickable.width < 720
                    ? welcomeFlickable.width : (welcomeFlickable.width - (root.compact ? 22 : 34)) * (1 - root.welcomeIntroShare)
                Layout.alignment: Qt.AlignTop
                implicitHeight: welcomeSetupColumn.implicitHeight + 28
                surfaceDialect: "material"
                elevation: 2
                borderless: root.welcomeBorderless
                outlined: false
                radiusOverride: root.welcomePlateRadius

                ColumnLayout {
                    id: welcomeSetupColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: "dashboard"
                            iconSize: 20
                            color: root.welcomeAccent
                        }
                        WelcomeText {
                            text: Translation.tr("Desktop family")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontSection
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                    }

                    WelcomeText {
                        Layout.fillWidth: true
                        text: Translation.tr("You can change this later in Settings.")
                        font.pixelSize: root.welcomeFontCaption
                        color: root.welcomeSecondaryText
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: Plugins.families
                        WelcomeChoiceRow {
                            required property string modelData
                            readonly property var manifest: Plugins.manifests[modelData] ?? ({})
                            title: String(manifest.name ?? modelData)
                            detail: Translation.tr(String(manifest.tagline ?? ""))
                            symbol: String(manifest.icon ?? "deployed_code")
                            selected: root.family === modelData
                            onClicked: root.chooseFamily(modelData)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.minimumHeight: 4
                    }

                    Rectangle {
                        visible: !root.familyWelcome?.intro
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                    }

                    RowLayout {
                        visible: !root.familyWelcome?.intro
                        Layout.fillWidth: true
                        spacing: 10

                        WelcomeText {
                            text: Translation.tr("Up next")
                            font.pixelSize: root.welcomeFontMeta
                            font.weight: Font.DemiBold
                            color: root.welcomeSecondaryText
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 20
                            color: ColorUtils.applyAlpha(root.welcomeOutline, 0.42)
                        }

                        Repeater {
                            model: root.steps.slice(1, 4)
                            RowLayout {
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 6

                                WelcomeText {
                                    text: String(index + 2).padStart(2, "0")
                                    font.family: root.welcomeFontNumbers
                                    font.pixelSize: root.welcomeFontMeta
                                    font.weight: Font.DemiBold
                                    color: root.welcomeAccent
                                }
                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: 16
                                    color: root.welcomeSecondaryText
                                }
                                WelcomeText {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.pixelSize: root.welcomeFontCaption
                                    font.weight: Font.Medium
                                    color: root.welcomeOnSurface
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
