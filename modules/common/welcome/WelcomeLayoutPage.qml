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
    id: layoutFlickable
    width: root.stepWidth
    contentHeight: layoutColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    bottomMargin: 24
    topMargin: Math.max(root.compact ? 8 : 12,
        Math.min(root.compact ? 20 : 28,
            Math.round((height - layoutColumn.implicitHeight - bottomMargin) / 2)))

    GridLayout {
        id: layoutColumn
        width: parent.width
        columns: layoutFlickable.width < 760 ? 1 : 2
        columnSpacing: root.compact ? 22 : 30
        rowSpacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: layoutFlickable.width < 760
                ? layoutFlickable.width : (layoutFlickable.width - (root.compact ? 22 : 30)) * 0.42
            Layout.alignment: Qt.AlignTop
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialSymbol { text: "dashboard"; iconSize: 18; color: root.welcomeAccent }
                WelcomeText {
                    text: Translation.tr("Shell family")
                    font.family: root.welcomeFontTitle
                    font.pixelSize: root.welcomeFontSection
                    font.weight: Font.Bold
                    color: root.welcomeOnSurface
                }
            }

            WelcomeText {
                Layout.fillWidth: true
                text: Translation.tr("Choose the shell family that matches how you want the desktop to work.")
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
        }

        PanelSurface {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: layoutFlickable.width < 760
                ? layoutFlickable.width : (layoutFlickable.width - (root.compact ? 22 : 30)) * 0.58
            Layout.alignment: Qt.AlignTop
            implicitHeight: Math.max(placementColumn.implicitHeight + 28, root.compact ? 300 : 330)
            surfaceDialect: "material"
            elevation: 2
            outlined: false
            radiusOverride: 16

            ColumnLayout {
                id: placementColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialCookie {
                        implicitSize: 34
                        sides: 8
                        color: root.welcomeAccentContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "view_compact"
                            iconSize: 17
                            color: root.welcomeAccent
                        }
                    }
                    WelcomeText {
                        text: Translation.tr("Placement")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    WelcomeText {
                        text: Translation.tr("Bar position")
                        font.pixelSize: root.welcomeFontBody
                        font.weight: Font.Medium
                        color: root.welcomeOnSurface
                    }
                    WelcomeSegmentedControl {
                        Layout.fillWidth: true
                        currentValue: (Config.options?.bar?.bottom ?? false) ? "bottom" : "top"
                        options: [
                            { displayName: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                            { displayName: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" }
                        ]
                        onSelected: value => root.setProfileFeature("bar.bottom", value === "bottom")
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    WelcomeText {
                        text: Translation.tr("Dock position")
                        font.pixelSize: root.welcomeFontBody
                        font.weight: Font.Medium
                        color: root.welcomeOnSurface
                    }
                    WelcomeSegmentedControl {
                        Layout.fillWidth: true
                        currentValue: Config.options?.dock?.position ?? "bottom"
                        options: [
                            { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: "bottom" },
                            { displayName: Translation.tr("Left"), icon: "arrow_back", value: "left" },
                            { displayName: Translation.tr("Right"), icon: "arrow_forward", value: "right" }
                        ]
                        onSelected: value => root.setProfileFeature("dock.position", value)
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 6
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: (Config.options?.panelFamily ?? "ii") === "ii"
                        && (Config.options?.bar?.appearanceStyle ?? "m3") === "m3"
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: "side_navigation"
                            iconSize: 18
                            color: root.welcomeAccent
                        }
                        WelcomeText {
                            text: Translation.tr("Sidebar access")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontSection
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                        Item { Layout.fillWidth: true }
                        WelcomeText {
                            text: Translation.tr("M3 bar")
                            font.pixelSize: root.welcomeFontMeta
                            font.weight: Font.Bold
                            color: root.welcomeAccentAlt
                        }
                    }

                    WelcomeText {
                        Layout.fillWidth: true
                        text: Translation.tr("A sidebar button stays at each outer edge of the bar.")
                        font.pixelSize: root.welcomeFontCaption
                        color: root.welcomeSecondaryText
                        wrapMode: Text.WordWrap
                    }

                    PanelSurface {
                        Layout.fillWidth: true
                        implicitHeight: 116
                        surfaceDialect: "material"
                        elevation: 1
                        outlined: false
                        radiusOverride: 14

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 7

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                WelcomeText {
                                    text: Translation.tr("Edge controls")
                                    font.pixelSize: root.welcomeFontMeta
                                    font.weight: Font.DemiBold
                                    color: root.welcomeSecondaryText
                                }

                                Item { Layout.fillWidth: true }

                                WelcomeText {
                                    text: "M3 · COMPACT"
                                    font.family: root.welcomeFontNumbers
                                    font.pixelSize: root.welcomeFontMeta
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.7
                                    color: root.welcomeAccentAlt
                                }
                            }

                            PanelSurface {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                surfaceDialect: "material"
                                elevation: 2
                                island: true
                                outlined: false
                                radiusOverride: 18

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 7
                                    anchors.rightMargin: 7
                                    spacing: 7

                                    PanelSurface {
                                        Layout.preferredWidth: 38
                                        Layout.preferredHeight: 38
                                        Layout.alignment: Qt.AlignVCenter
                                        surfaceDialect: "material"
                                        elevation: 3
                                        island: true
                                        outlined: false

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "left_panel_open"
                                            iconSize: 20
                                            color: root.welcomeAccent
                                        }
                                    }

                                    RowLayout {
                                        spacing: 4
                                        Layout.alignment: Qt.AlignVCenter

                                        Rectangle {
                                            implicitWidth: 18
                                            implicitHeight: 8
                                            radius: 4
                                            color: root.welcomeAccent
                                        }
                                        Rectangle {
                                            implicitWidth: 8
                                            implicitHeight: 8
                                            radius: 4
                                            color: ColorUtils.applyAlpha(root.welcomeOnSurfaceVariant, 0.34)
                                        }
                                        Rectangle {
                                            implicitWidth: 8
                                            implicitHeight: 8
                                            radius: 4
                                            color: ColorUtils.applyAlpha(root.welcomeOnSurfaceVariant, 0.34)
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    PanelSurface {
                                        Layout.preferredWidth: 156
                                        Layout.preferredHeight: 34
                                        Layout.alignment: Qt.AlignVCenter
                                        surfaceDialect: "material"
                                        elevation: 3
                                        island: true
                                        outlined: false

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Repeater {
                                                model: ["folder", "terminal", "language", "music_note"]
                                                MaterialSymbol {
                                                    required property string modelData
                                                    text: modelData
                                                    iconSize: 16
                                                    color: root.welcomeOnSurfaceVariant
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    RowLayout {
                                        spacing: 4
                                        Layout.alignment: Qt.AlignVCenter
                                        MaterialSymbol {
                                            text: "wifi"
                                            iconSize: 15
                                            color: root.welcomeOnSurfaceVariant
                                        }
                                        MaterialSymbol {
                                            text: "volume_up"
                                            iconSize: 15
                                            color: root.welcomeOnSurfaceVariant
                                        }
                                    }

                                    PanelSurface {
                                        Layout.preferredWidth: 38
                                        Layout.preferredHeight: 38
                                        Layout.alignment: Qt.AlignVCenter
                                        surfaceDialect: "material"
                                        elevation: 3
                                        island: true
                                        outlined: false

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "right_panel_open"
                                            iconSize: 20
                                            color: root.welcomeAccent
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                RowLayout {
                                    spacing: 5
                                    MaterialSymbol {
                                        text: "left_panel_open"
                                        iconSize: 14
                                        color: root.welcomeAccent
                                    }
                                    WelcomeText {
                                        text: Translation.tr("Left sidebar")
                                        font.pixelSize: root.welcomeFontMeta
                                        font.weight: Font.Medium
                                        color: root.welcomeOnSurface
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    spacing: 5
                                    WelcomeText {
                                        text: Translation.tr("Right sidebar")
                                        font.pixelSize: root.welcomeFontMeta
                                        font.weight: Font.Medium
                                        color: root.welcomeOnSurface
                                    }
                                    MaterialSymbol {
                                        text: "right_panel_open"
                                        iconSize: 14
                                        color: root.welcomeAccent
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: (Config.options?.panelFamily ?? "ii") === "ii"
                        && (Config.options?.bar?.appearanceStyle ?? "m3") !== "m3"
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: "side_navigation"
                            iconSize: 18
                            color: root.welcomeAccentAlt
                        }
                        WelcomeText {
                            Layout.fillWidth: true
                            text: Translation.tr("Sidebar access")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontSection
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                        WelcomeText {
                            text: String(Config.options?.bar?.appearanceStyle ?? "m3").toUpperCase()
                            font.family: root.welcomeFontNumbers
                            font.pixelSize: root.welcomeFontMeta
                            font.weight: Font.Bold
                            color: root.welcomeAccentAlt
                        }
                    }

                    PanelSurface {
                        Layout.fillWidth: true
                        implicitHeight: 82
                        surfaceDialect: "material"
                        elevation: 1
                        outlined: false
                        radiusOverride: 14

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            MaterialCookie {
                                implicitSize: 42
                                sides: 7
                                color: ColorUtils.mix(root.welcomeSurfaceHighest, root.welcomeAccentAlt, 0.62)
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "visibility"
                                    iconSize: 20
                                    color: root.welcomeAccentAlt
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                WelcomeText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Sidebars stay available")
                                    font.family: root.welcomeFontTitle
                                    font.pixelSize: root.welcomeFontBody
                                    font.weight: Font.Bold
                                    color: root.welcomeOnSurface
                                }
                                WelcomeText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("This bar style uses its own controls; your sidebars remain available.")
                                    font.pixelSize: root.welcomeFontCaption
                                    color: root.welcomeSecondaryText
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
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
