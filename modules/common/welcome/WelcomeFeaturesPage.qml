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
    id: featuresFlickable
    width: root.stepWidth
    contentHeight: featuresColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    bottomMargin: 24
    topMargin: Math.max(root.compact ? 8 : 12,
        Math.min(root.compact ? 20 : 28,
            Math.round((height - featuresColumn.implicitHeight - bottomMargin) / 2)))

    readonly property var profileHighlights: root.selectedProfile === "minimum" ? [
        { value: "M3", label: Translation.tr("compact bar") },
        { value: "2", label: Translation.tr("sidebars") },
        { value: "4", label: Translation.tr("quick toggles") },
        { value: "0", label: Translation.tr("desktop widgets") }
    ] : root.selectedProfile === "full" ? [
        { value: "M3+", label: Translation.tr("bar + media") },
        { value: "2", label: Translation.tr("full sidebars") },
        { value: "8", label: Translation.tr("quick toggles") },
        { value: "2", label: Translation.tr("desktop widgets") }
    ] : [
        { value: "M3", label: Translation.tr("bar + dock") },
        { value: "2", label: Translation.tr("sidebars") },
        { value: "8", label: Translation.tr("quick toggles") },
        { value: "1", label: Translation.tr("desktop clock") }
    ]

    GridLayout {
        id: featuresColumn
        width: parent.width
        columns: featuresFlickable.width < 760 ? 1 : 2
        columnSpacing: root.compact ? 22 : 30
        rowSpacing: 16

        ColumnLayout {
            visible: root.welcomeProfiles
            Layout.fillWidth: true
            Layout.preferredWidth: featuresFlickable.width < 760
                ? featuresFlickable.width : (featuresFlickable.width - (root.compact ? 22 : 30)) * 0.38
            Layout.alignment: Qt.AlignTop
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialSymbol { text: "tune"; iconSize: 18; color: root.welcomeAccent }
                WelcomeText {
                    text: Translation.tr("Base setup")
                    font.family: root.welcomeFontTitle
                    font.pixelSize: root.welcomeFontSection
                    font.weight: Font.Bold
                    color: root.welcomeOnSurface
                }
            }

            WelcomeText {
                Layout.fillWidth: true
                text: Translation.tr("Choose how much iNiR sets up for your first session.")
                font.pixelSize: root.welcomeFontCaption
                color: root.welcomeSecondaryText
                wrapMode: Text.WordWrap
            }

            WelcomeChoiceRow {
                title: Translation.tr("Minimum")
                detail: Translation.tr("Core controls with no desktop widgets.")
                symbol: "filter_1"
                selected: !root.profileCustomized && root.selectedProfile === "minimum"
                onClicked: root.applyProfile("minimum")
            }

            WelcomeChoiceRow {
                title: Translation.tr("Balanced")
                detail: Translation.tr("Sidebars, daily toggles and a desktop clock.")
                symbol: "tune"
                badge: Translation.tr("Recommended")
                selected: !root.profileCustomized && root.selectedProfile === "balanced"
                onClicked: root.applyProfile("balanced")
            }

            WelcomeChoiceRow {
                title: Translation.tr("Full")
                detail: Translation.tr("More local tools, fuller sidebars and a system monitor.")
                symbol: "auto_awesome"
                selected: !root.profileCustomized && root.selectedProfile === "full"
                onClicked: root.applyProfile("full")
            }
        }

        PanelSurface {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: featuresFlickable.width < 760
                ? featuresFlickable.width : (featuresFlickable.width - (root.compact ? 22 : 30)) * 0.62
            Layout.alignment: Qt.AlignTop
            implicitHeight: root.welcomeProfiles ? Math.max(profileSummaryColumn.implicitHeight + 28, root.compact ? 300 : 330)
                : profileSummaryColumn.implicitHeight + 28
            surfaceDialect: "material"
            elevation: 2
            outlined: false
            radiusOverride: 16

            ColumnLayout {
                id: profileSummaryColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    visible: root.welcomeProfiles
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialCookie {
                        implicitSize: 38
                        sides: 8
                        color: root.welcomeAccentContainer
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.selectedProfile === "minimum" ? "filter_1"
                                : root.selectedProfile === "full" ? "auto_awesome" : "tune"
                            iconSize: 19
                            color: root.welcomeAccent
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        WelcomeText {
                            text: root.profileCustomized
                                ? Translation.tr("Custom setup") : root.selectedProfileTitle
                            font.family: root.welcomeFontTitle
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                        WelcomeText {
                            Layout.fillWidth: true
                            text: root.selectedProfileDescription
                            font.pixelSize: root.welcomeFontCaption
                            font.weight: Font.Medium
                            color: root.welcomeSecondaryText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }

                GridLayout {
                    visible: root.welcomeProfiles
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 2
                    Repeater {
                        model: featuresFlickable.profileHighlights
                        WelcomeMetric {
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            value: modelData.value
                            label: modelData.label
                            accent: index % 2 === 0 ? root.welcomeAccent : root.welcomeAccentAlt
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 4
                }

                Rectangle {
                    visible: root.welcomeProfiles
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol { text: "speed"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("Effects")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                    Item { Layout.fillWidth: true }
                    WelcomeText {
                        text: root.effectivePerformancePreset === "custom"
                            ? Translation.tr("Custom") : root.currentPerformancePreset.name
                        font.pixelSize: root.welcomeFontMeta
                        color: root.welcomeSecondaryText
                    }
                }

                WelcomeSegmentedControl {
                    Layout.fillWidth: true
                    currentValue: root.effectivePerformancePreset
                    options: root.performancePresets.map(preset => ({
                        displayName: preset.name,
                        icon: preset.icon,
                        value: preset.id
                    }))
                    onSelected: value => root.applyPerformancePreset(value)
                }

                WelcomeText {
                    Layout.fillWidth: true
                    text: root.currentPerformancePresetDescription
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
