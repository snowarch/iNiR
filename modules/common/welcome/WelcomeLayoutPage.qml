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

                Repeater {
                    model: root.placementRows.length

                    ColumnLayout {
                        id: placementRow
                        required property int index
                        readonly property var row: root.placementRows[index]
                        Layout.fillWidth: true
                        spacing: 5
                        WelcomeText {
                            text: placementRow.row.label
                            font.pixelSize: root.welcomeFontBody
                            font.weight: Font.Medium
                            color: root.welcomeOnSurface
                        }
                        WelcomeSegmentedControl {
                            Layout.fillWidth: true
                            currentValue: Config.getNestedValue(placementRow.row.key, placementRow.row.fallback)
                            options: placementRow.row.options
                            onSelected: value => root.setProfileFeature(placementRow.row.key, value)
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 6
                }

                // what the family adds under its placement rows (Material: how its sidebars open)
                Loader {
                    Layout.fillWidth: true
                    active: !!root.familyWelcome?.layoutExtra
                    visible: active
                    sourceComponent: root.familyWelcome?.layoutExtra ?? null
                }
            }
        }
    }
}
