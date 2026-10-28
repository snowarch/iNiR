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
    id: readyFlickable
    width: root.stepWidth
    contentHeight: readyColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    bottomMargin: 12
    topMargin: Math.max(root.compact ? 8 : 12,
        Math.min(root.compact ? 12 : 16,
            Math.round((height - readyColumn.implicitHeight - bottomMargin) / 2)))

    ColumnLayout {
        id: readyColumn
        width: parent.width
        spacing: root.compact ? 10 : 14

        PanelSurface {
            Layout.fillWidth: true
            implicitHeight: readySummaryColumn.implicitHeight + 24
            surfaceDialect: "material"
            elevation: 2
            borderless: root.welcomeBorderless
            outlined: false
            radiusOverride: root.welcomePlateRadius

            WelcomeFill {}

            ColumnLayout {
                id: readySummaryColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Loader {
                        active: !!root.familyWelcome?.mark
                        visible: active
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        sourceComponent: root.familyWelcome?.mark ?? null
                    }
                    MaterialCookie {
                        visible: !root.familyWelcome?.mark
                        implicitSize: 46
                        sides: 8
                        color: root.welcomeAccentContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "check"
                            iconSize: 24
                            color: root.welcomeAccent
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        WelcomeText {
                            text: Translation.tr("Setup ready")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: Appearance.font.pixelSize.large * 1.08
                            font.weight: Font.DemiBold
                            color: root.welcomeOnSurface
                        }
                        WelcomeText {
                            Layout.fillWidth: true
                            text: Translation.tr("You can change any of this later in Settings.")
                            font.pixelSize: root.welcomeFontCaption
                            color: root.welcomeSecondaryText
                            wrapMode: Text.WordWrap
                        }
                    }

                    MascotImage {
                        previewMode: true
                        pose: "about-confident"
                        visible: status === Image.Ready && readyFlickable.width >= 720
                        Layout.preferredWidth: visible ? 80 : 0
                        Layout.preferredHeight: visible ? 90 : 0
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: ColorUtils.applyAlpha(root.welcomeOutline, 0.32)
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: readyFlickable.width < 720 ? 2 : 4
                    columnSpacing: 18
                    rowSpacing: 8

                    Repeater {
                        model: [
                            { icon: "tune", label: Translation.tr("Starting point"), value: root.familyWelcome?.startSummary ?? root.selectedProfileTitle },
                            { icon: "palette", label: Translation.tr("Style"), value: root.familyWelcome?.styleSummary
                                ?? (root.effectiveStylePreset === "custom" ? Translation.tr("Custom") : root.currentStylePreset.name) },
                            { icon: "dashboard", label: Translation.tr("Family"), value: root.familyTitle },
                            { icon: "speed", label: Translation.tr("Effects"), value: root.effectivePerformancePreset === "custom" ? Translation.tr("Custom") : root.currentPerformancePreset.name }
                        ]

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 17
                                color: root.welcomeAccent
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                WelcomeText {
                                    text: modelData.label
                                    font.pixelSize: root.welcomeFontMeta
                                    color: root.welcomeSecondaryText
                                }
                                WelcomeText {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    font.pixelSize: root.welcomeFontCaption
                                    font.weight: Font.DemiBold
                                    color: root.welcomeOnSurface
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }

        // Two task columns use the full content field. Like Dashboard, each
        // column owns one semantic group instead of stacking decorative cards.
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            columns: readyFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 10 : 14
            rowSpacing: root.compact ? 10 : 14

            // Keyboard shortcuts card
            PanelSurface {
                Layout.fillWidth: true
                Layout.preferredWidth: readyFlickable.width < 760 ? readyFlickable.width : 420
                Layout.alignment: Qt.AlignTop
                implicitHeight: shortcutsCardCol.implicitHeight + 20
                surfaceDialect: "material"
                elevation: 1
                borderless: root.welcomeBorderless
                outlined: false
                radiusOverride: root.welcomePlateRadius

                WelcomeFill {}

                ColumnLayout {
                    id: shortcutsCardCol
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        MaterialSymbol { text: "keyboard"; iconSize: 18; color: root.welcomeAccent }
                        WelcomeText {
                            text: Translation.tr("Keyboard")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }
                        Item { Layout.fillWidth: true }
                        WelcomeText {
                            text: Translation.tr("Full list: Super+/")
                            font.pixelSize: root.welcomeFontMeta
                            color: root.welcomeSecondaryText
                        }
                    }

                    Repeater {
                        model: [
                            { keys: "Super+/",     desc: Translation.tr("All shortcuts") },
                            { keys: "Super+Space", desc: Translation.tr("App launcher") },
                            { keys: "Super+,",     desc: Translation.tr("Settings") },
                            { keys: "Super+V",     desc: Translation.tr("Clipboard history") }
                        ]
                        RowLayout {
                            Layout.fillWidth: true
                            required property var modelData
                            spacing: 10

                            Row {
                                Layout.preferredWidth: root.compact ? 138 : 154
                                spacing: 2
                                Repeater {
                                    model: modelData.keys.split("+")
                                    WelcomeKey {
                                        required property string modelData
                                        key: modelData
                                    }
                                }
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: modelData.desc
                                font.pixelSize: root.welcomeFontCaption
                                color: root.welcomeSecondaryText
                                horizontalAlignment: Text.AlignLeft
                            }
                        }
                    }
                }
            }

            // Try it now — interactive action card
            PanelSurface {
                Layout.fillWidth: true
                Layout.preferredWidth: readyFlickable.width < 760 ? readyFlickable.width : 580
                Layout.alignment: Qt.AlignTop
                implicitHeight: tryItCardCol.implicitHeight + 20
                surfaceDialect: "material"
                elevation: 2
                borderless: root.welcomeBorderless
                outlined: false
                radiusOverride: root.welcomePlateRadius

                WelcomeFill {}

                ColumnLayout {
                    id: tryItCardCol
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol { text: "rocket_launch"; iconSize: 18; color: root.welcomeAccent }
                        WelcomeText {
                            text: Translation.tr("Quick actions")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Repeater {
                        model: [
                            {
                                icon: "tune",
                                label: Translation.tr("Open quick settings"),
                                sub: Translation.tr("Network, audio and brightness"),
                                target: "controlPanel",
                                fn: "toggle"
                            },
                            {
                                icon: "wallpaper",
                                label: Translation.tr("Pick a wallpaper"),
                                sub: Translation.tr("Choose a background"),
                                target: "wallpaperSelector",
                                fn: "toggle"
                            },
                            {
                                icon: "keyboard",
                                label: Translation.tr("Show all shortcuts"),
                                sub: Translation.tr("Open the full shortcut list"),
                                target: "cheatsheet",
                                fn: "toggle"
                            }
                        ]
                        WelcomeListAction {
                            Layout.fillWidth: true
                            required property var modelData
                            materialIcon: modelData.icon
                            title: modelData.label
                            subtitle: modelData.sub

                            onClicked: Quickshell.execDetached([
                                Quickshell.shellPath("scripts/inir"),
                                modelData.target,
                                modelData.fn
                            ])
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 6

            Item { Layout.fillWidth: true }

            WelcomeActionButton {
                materialIcon: "settings"
                label: Translation.tr("Settings")
                onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
            }

            WelcomeActionButton {
                materialIcon: "open_in_new"
                label: Translation.tr("Troubleshoot")
                onClicked: Qt.openUrlExternally("https://inir.space/docs/limitations/")
            }

            WelcomeActionButton {
                materialIcon: "menu_book"
                label: Translation.tr("Docs")
                onClicked: Qt.openUrlExternally("https://inir.space/docs/")
            }

            WelcomeActionButton {
                materialIcon: "bug_report"
                label: Translation.tr("Report")
                onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/issues")
            }
        }

        Item { Layout.preferredHeight: 2 }
    }
}
