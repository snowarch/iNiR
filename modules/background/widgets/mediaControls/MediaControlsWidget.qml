pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import qs.services
import qs
import qs.modules.common.functions
import qs.modules.background.widgets
import qs.modules.mediaControls.presets

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

AbstractBackgroundWidget {
    id: root

    configEntryName: "mediaControls"

    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

    // Use MprisController.displayPlayers - centralized filtering
    readonly property var meaningfulPlayers: MprisController.displayPlayers

    implicitWidth: widgetWidth
    implicitHeight: playerColumnLayout.implicitHeight

    readonly property bool visualizerActive: (Config.options?.background?.widgets?.mediaControls?.enable ?? false)
        && (root.meaningfulPlayers?.length ?? 0) > 0

    CavaProcess {
        id: cavaProcess
        active: root.visualizerActive
    }

    property list<real> visualizerPoints: cavaProcess.points

    readonly property point widgetScreenPos: root.mapToItem(null, 0, 0)
    
    // Get selected preset component
    readonly property string selectedPreset: Config.options?.background?.widgets?.mediaControls?.playerPreset ?? "full"
    readonly property Component presetComponent: {
        switch (selectedPreset) {
            case "compact": return compactPlayerComponent
            case "minimal": return minimalPlayerComponent
            case "albumart": return albumArtPlayerComponent
            case "visualizer": return visualizerPlayerComponent
            case "classic": return classicPlayerComponent
            case "full":
            default: return fullPlayerComponent
        }
    }
    
    // Preset components
    Component {
        id: fullPlayerComponent
        FullPlayer {}
    }
    
    Component {
        id: compactPlayerComponent
        CompactPlayer {}
    }
    
    Component {
        id: minimalPlayerComponent
        MinimalPlayer {}
    }
    
    Component {
        id: albumArtPlayerComponent
        AlbumArtPlayer {}
    }
    
    Component {
        id: visualizerPlayerComponent
        VisualizerPlayer {}
    }
    
    Component {
        id: classicPlayerComponent
        ClassicPlayer {}
    }

    ColumnLayout {
        id: playerColumnLayout
        anchors.fill: parent
        spacing: -Appearance.sizes.elevationMargin

        Repeater {
            model: ScriptModel {
                values: root.meaningfulPlayers
            }
            delegate: Loader {
                required property MprisPlayer modelData
                sourceComponent: root.presetComponent
                Layout.preferredWidth: root.widgetWidth
                Layout.preferredHeight: root.widgetHeight
                
                onLoaded: {
                    item.player = modelData
                    item.visualizerPoints = Qt.binding(() => root.visualizerPoints)
                    item.radius = root.popupRounding
                    item.screenX = Qt.binding(() => root.widgetScreenPos.x)
                    item.screenY = Qt.binding(() => root.widgetScreenPos.y)
                }
            }
        }

        Item {
            Layout.fillWidth: true
            visible: root.meaningfulPlayers.length === 0
            implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
            implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

            StyledRectangularShadow {
                target: placeholderBackground
                visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
            }

            Rectangle {
                id: placeholderBackground
                anchors.centerIn: parent
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface
                     : Appearance.colors.colLayer0
                radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.popupRounding
                border.width: Appearance.inirEverywhere || Appearance.auroraEverywhere ? 1 : 0
                border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
                            : "transparent"
                property real padding: 20
                implicitWidth: placeholderLayout.implicitWidth + padding * 2
                implicitHeight: placeholderLayout.implicitHeight + padding * 2

                ColumnLayout {
                    id: placeholderLayout
                    anchors.centerIn: parent

                    StyledText {
                        text: Translation.tr("No active player")
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.inirEverywhere ? Appearance.inir.colText
                            : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                            : Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                            : Appearance.auroraEverywhere ? Appearance.aurora.colTextSecondary
                            : Appearance.colors.colSubtext
                        text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
