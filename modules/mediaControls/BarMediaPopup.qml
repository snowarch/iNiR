pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import "root:"

Item {
    id: root
    signal closeRequested()

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    // Use MprisController.displayPlayers - centralized filtering
    readonly property var meaningfulPlayers: MprisController.displayPlayers
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real popupRounding: Appearance.rounding.normal
    
    // Cache to prevent flickering during track transitions
    property var _playerCache: []
    property bool _cacheValid: false

    onMeaningfulPlayersChanged: {
        const count = root.meaningfulPlayers?.length ?? 0
        if (count > 0) {
            root._playerCache = [...root.meaningfulPlayers];
            root._cacheValid = true;
            cacheInvalidateTimer.stop();
        } else if (root._cacheValid && root._playerCache.length > 0) {
            // Keep cache during transitions
            cacheInvalidateTimer.restart();
        }
    }

    Timer {
        id: cacheInvalidateTimer
        interval: 800  // Longer debounce for track transitions
        onTriggered: {
            if ((root.meaningfulPlayers?.length ?? 0) === 0) {
                root._cacheValid = false;
            }
        }
    }

    implicitWidth: widgetWidth
    implicitHeight: playerColumn.implicitHeight

    ColumnLayout {
        id: playerColumn
        anchors.fill: parent
        spacing: 8

        Repeater {
            model: ScriptModel {
                values: root._cacheValid ? root._playerCache : (root.meaningfulPlayers ?? [])
            }
            delegate: Item {
                required property MprisPlayer modelData
                required property int index
                Layout.fillWidth: true
                implicitWidth: root.widgetWidth
                implicitHeight: root.widgetHeight + (isActive && (root._cacheValid ? root._playerCache : (root.meaningfulPlayers ?? [])).length > 1 ? 4 : 0)
                
                readonly property bool isActive: modelData === MprisController.trackedPlayer
                
                Rectangle {
                    visible: (root._cacheValid ? root._playerCache : (root.meaningfulPlayers ?? [])).length > 1
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Appearance.sizes.elevationMargin
                    width: 3
                    radius: 2
                    color: isActive 
                        ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                        : (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colLayer2 : Appearance.colors.colLayer2)
                    
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: 150 }
                    }
                }
                
                PlayerControl {
                    anchors.fill: parent
                    anchors.leftMargin: (root._cacheValid ? root._playerCache : (root.meaningfulPlayers ?? [])).length > 1 ? 6 : 0
                    player: modelData
                    visualizerPoints: []
                    radius: root.popupRounding
                }
                
                MouseArea {
                    anchors.fill: parent
                    visible: !isActive && (root._cacheValid ? root._playerCache : (root.meaningfulPlayers ?? [])).length > 1
                    onClicked: MprisController.setActivePlayer(modelData)
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                }
            }
        }

        // No player placeholder - only show if truly no players after debounce
        Item {
            id: placeholderItem
            // Never show placeholder while cache is valid (during transitions)
            visible: !root._cacheValid && (root.meaningfulPlayers?.length ?? 0) === 0 && (Mpris.players.values?.length ?? 0) === 0
            Layout.fillWidth: true
            implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
            implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

            StyledRectangularShadow {
                target: placeholderBackground
            }

            Rectangle {
                id: placeholderBackground
                anchors.centerIn: parent
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colLayer1
                    : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colPopupSurface
                     : Appearance.colors.colLayer0
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                    : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.roundingNormal : root.popupRounding
                border.width: Appearance.angelEverywhere ? 0 : ((Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0)
                border.color: Appearance.angelEverywhere ? "transparent"
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colBorder
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colPopupBorder
                            : "transparent"
                property real padding: 20

                AngelPartialBorder { targetRadius: placeholderBackground.radius; coverage: 0.5 }
                implicitWidth: placeholderLayout.implicitWidth + padding * 2
                implicitHeight: placeholderLayout.implicitHeight + padding * 2

                ColumnLayout {
                    id: placeholderLayout
                    anchors.centerIn: parent

                    StyledText {
                        text: Translation.tr("No active player")
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.angelEverywhere ? Appearance.angel.colText
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colText
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.colors.colOnLayer0
                            : Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colTextSecondary
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colTextSecondary
                            : Appearance.colors.colSubtext
                        text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
