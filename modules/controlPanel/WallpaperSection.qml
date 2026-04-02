pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: wallpaperLayout.implicitHeight + 16
    readonly property bool showSchemeChips: Config.options?.controlPanel?.showWallpaperSchemeChips ?? false
    
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
         : inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : inirEverywhere ? Appearance.inir.colLayer1
         : auroraEverywhere ? Appearance.aurora.colSubSurface
         : Appearance.colors.colLayer1
    border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
               : inirEverywhere ? 1 : 0
    border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
               : inirEverywhere ? Appearance.inir.colBorder : "transparent"

    ColumnLayout {
        id: wallpaperLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "wallpaper"
                iconSize: 16
                color: root.inirEverywhere ? Appearance.inir.colPrimary
                     : root.auroraEverywhere ? Appearance.m3colors.m3primary
                     : Appearance.colors.colPrimary
            }

            StyledText {
                text: Translation.tr("Wallpaper")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.inirEverywhere ? Appearance.inir.colText
                     : root.auroraEverywhere ? Appearance.m3colors.m3onSurface
                     : Appearance.colors.colOnLayer1
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitWidth: 26
                implicitHeight: 26
                buttonRadius: root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: root.inirEverywhere ? Appearance.inir.colLayer2Hover 
                    : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                    : Appearance.colors.colLayer2Hover
                onClicked: Wallpapers.randomFromCurrentFolder()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "shuffle"
                    iconSize: 14
                    color: root.inirEverywhere ? Appearance.inir.colTextSecondary
                         : root.auroraEverywhere ? Appearance.m3colors.m3onSurfaceVariant
                         : Appearance.colors.colSubtext
                }
                StyledToolTip { text: Translation.tr("Random") }
            }

            RippleButton {
                implicitWidth: 26
                implicitHeight: 26
                buttonRadius: root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: root.inirEverywhere ? Appearance.inir.colLayer2Hover 
                    : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                    : Appearance.colors.colLayer2Hover
                onClicked: GlobalActions.runLauncher(["wallpaperSelector", "toggle"])
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "folder_open"
                    iconSize: 14
                    color: root.inirEverywhere ? Appearance.inir.colTextSecondary
                         : root.auroraEverywhere ? Appearance.m3colors.m3onSurfaceVariant
                         : Appearance.colors.colSubtext
                }
                StyledToolTip { text: Translation.tr("Browse") }
            }
        }

        // Preview
        Item {
            id: previewContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 100

            Rectangle {
                id: previewMask
                anchors.fill: parent
                radius: root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                visible: false
            }

            Image {
                id: wallpaperPreview
                anchors.fill: parent
                source: Wallpapers.effectiveWallpaperUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                sourceSize.width: previewContainer.width * 2
                sourceSize.height: previewContainer.height * 2
                layer.enabled: true
                layer.effect: GE.OpacityMask {
                    maskSource: previewMask
                }
            }

            // Dark fade at bottom (masked to match preview corners)
            Item {
                id: fadeContainer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 32

                Rectangle {
                    id: fadeMask
                    anchors.fill: parent
                    radius: root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                    visible: false
                }

                Rectangle {
                    id: fadeRect
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.4) }
                    }
                    visible: false
                }

                GE.OpacityMask {
                    anchors.fill: parent
                    source: fadeRect
                    maskSource: fadeMask
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.showSchemeChips
            sourceComponent: ConfigSelectionArray {
                Layout.fillWidth: true
                currentValue: Config.options?.appearance?.palette?.type ?? "auto"
                onSelected: newValue => {
                    Config.setNestedValue("appearance.palette.type", newValue)
                    if (ThemeService.isAutoTheme) {
                        Quickshell.execDetached(["/usr/bin/bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch --type ${newValue}`]);
                    } else {
                        const hex = MaterialThemeLoader.colorToHex(Appearance.m3colors.m3primary)
                        MaterialThemeLoader.applySchemeVariant(hex, newValue)
                    }
                }
                options: [
                    { "value": "auto", "displayName": Translation.tr("Auto") },
                    { "value": "scheme-content", "displayName": Translation.tr("Content") },
                    { "value": "scheme-expressive", "displayName": Translation.tr("Expressive") },
                    { "value": "scheme-fidelity", "displayName": Translation.tr("Fidelity") },
                    { "value": "scheme-fruit-salad", "displayName": Translation.tr("Fruit Salad") },
                    { "value": "scheme-monochrome", "displayName": Translation.tr("Monochrome") },
                    { "value": "scheme-neutral", "displayName": Translation.tr("Neutral") },
                    { "value": "scheme-rainbow", "displayName": Translation.tr("Rainbow") },
                    { "value": "scheme-tonal-spot", "displayName": Translation.tr("Tonal Spot") }
                ]
            }
        }
    }
}
