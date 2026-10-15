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
    readonly property var _visiblePlayers: root._cacheValid ? root._playerCache : (root.meaningfulPlayers ?? [])

    function _samePlayerOrder(a, b): bool {
        if ((a?.length ?? 0) !== (b?.length ?? 0)) return false
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false
        }
        return true
    }

    onMeaningfulPlayersChanged: {
        const nextPlayers = root.meaningfulPlayers ?? []
        const count = nextPlayers.length
        if (count > 0) {
            if (!root._cacheValid || !root._samePlayerOrder(nextPlayers, root._playerCache))
                root._playerCache = [...nextPlayers];
            root._cacheValid = true;
            cacheInvalidateTimer.stop();
        } else if (root._cacheValid && root._playerCache.length > 0) {
            // Keep cache during transitions
            cacheInvalidateTimer.restart();
        }
    }

    Timer {
        id: cacheInvalidateTimer
        interval: 2200
        onTriggered: {
            if ((root.meaningfulPlayers?.length ?? 0) === 0 && (Mpris.players.values?.length ?? 0) === 0) {
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
                values: root._visiblePlayers
            }
            delegate: Item {
                required property MprisPlayer modelData
                required property int index
                Layout.fillWidth: true
                implicitWidth: root.widgetWidth
                implicitHeight: root.widgetHeight + (isActive && root._visiblePlayers.length > 1 ? 4 : 0)
                
                readonly property bool isActive: modelData === MprisController.trackedPlayer
                
                Rectangle {
                    visible: root._visiblePlayers.length > 1
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 0
                    anchors.topMargin: Appearance.sizes.elevationMargin
                    anchors.bottomMargin: Appearance.sizes.elevationMargin
                    width: 3
                    radius: 2
                    color: isActive
                        ? (Appearance.zzzEverywhere ? Appearance.zzz.accent
                            : Appearance.angelEverywhere ? Appearance.angel.colPrimary
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                        : (Appearance.zzzEverywhere ? Appearance.zzz.bg3
                            : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colLayer2 : Appearance.colors.colLayer2)
                    
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: 150 }
                    }
                }
                
                PlayerControl {
                    anchors.fill: parent
                    anchors.leftMargin: root._visiblePlayers.length > 1
                        ? Appearance.sizes.elevationMargin : 0
                    player: modelData
                    visualizerPoints: []
                    radius: root.popupRounding
                }
                
                MouseArea {
                    anchors.fill: parent
                    visible: !isActive && root._visiblePlayers.length > 1
                    onClicked: MprisController.setActivePlayer(modelData)
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                }
            }
        }

        // No player placeholder - only show if truly no players after debounce
        Item {
            id: placeholderItem
            readonly property bool _noPlayers: (root.meaningfulPlayers?.length ?? 0) === 0 && (Mpris.players.values?.length ?? 0) === 0
            readonly property bool _cacheEmpty: !root._cacheValid || root._playerCache.length === 0
            visible: _cacheEmpty && _noPlayers
            Layout.fillWidth: true
            implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
            implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

            StyledRectangularShadow {
                target: placeholderBackground
            }

            Rectangle {
                id: placeholderBackground
                anchors.centerIn: parent
                color: Appearance.zzzEverywhere ? Appearance.zzz.bg0
                    : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colLayer1
                    : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colPopupSurface
                     : Appearance.colors.colLayer0
                radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                    : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.roundingNormal : root.popupRounding
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                border.width: Appearance.zzzEverywhere ? 1 : (Appearance.angelEverywhere ? 0 : ((Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0))
                Behavior on border.width {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                border.color: Appearance.zzzEverywhere ? Appearance.zzz.borderColor
                            : Appearance.angelEverywhere ? "transparent"
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colBorder
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colPopupBorder
                            : "transparent"
                Behavior on border.color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
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
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                            : Appearance.angelEverywhere ? Appearance.angel.colText
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colText
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.colors.colOnLayer0
                            : Appearance.colors.colOnLayer0
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                    StyledText {
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ghostInk
                            : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colTextSecondary
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colTextSecondary
                            : Appearance.colors.colSubtext
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
