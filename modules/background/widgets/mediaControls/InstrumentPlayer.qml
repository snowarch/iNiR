pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.mediaControls.components
import qs.modules.background.widgets.instrument

// The player as an Instrument transport: framed cover, title in the display face, a position scale
// and two readings, drawn in the widget's wallpaper-sampled ink with no plate of its own.
Item {
    id: root

    required property var widget
    property MprisPlayer player: null
    readonly property real s: root.widget.scaleFactor
    readonly property color ink: root.widget.widgetInk
    readonly property color muted: root.widget.widgetInkMuted
    readonly property color accent: root.widget.widgetAccentVisible

    PlayerBase {
        id: playerBase
        player: root.player
        positionUpdatesActive: root.widget.visible && root.widget.powerActive
    }

    function clock(seconds: real): string {
        return StringUtils.friendlyTimeForSeconds(Math.max(0, seconds || 0))
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Math.round(12 * root.s)
        spacing: Math.round(14 * root.s)

        Item {
            Layout.preferredWidth: Math.round(84 * root.s)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: coverMask
                anchors.fill: parent
                radius: Math.round(6 * root.s)
                visible: false
            }
            Rectangle {
                anchors.fill: parent
                radius: coverMask.radius
                color: ColorUtils.applyAlpha(root.ink, 0.08)
                visible: cover.status !== Image.Ready
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: Math.round(26 * root.s)
                    color: root.muted
                }
            }
            Image {
                id: cover
                anchors.fill: parent
                source: playerBase.displayedArtFilePath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                sourceSize.width: Math.round(parent.width * 2)
                sourceSize.height: Math.round(parent.height * 2)
                layer.enabled: status === Image.Ready
                layer.effect: GE.OpacityMask { maskSource: coverMask }
            }
            InstrumentBrackets {
                anchors.fill: parent
                anchors.margins: -Math.round(3 * root.s)
                color: root.accent
                length: Math.round(12 * root.s)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Math.round(2 * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.s)
                Rectangle {
                    implicitWidth: Math.round(6 * root.s)
                    implicitHeight: implicitWidth
                    color: playerBase.effectiveIsPlaying ? root.accent : "transparent"
                    border.width: playerBase.effectiveIsPlaying ? 0 : 1
                    border.color: root.muted
                }
                InstrumentLabel {
                    Layout.fillWidth: true
                    text: playerBase.effectiveIsPlaying ? Translation.tr("Transport / Playing") : Translation.tr("Transport / Paused")
                    color: root.accent
                    scaleFactor: root.s
                    strong: true
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: StringUtils.cleanMusicTitle(playerBase.effectiveTitle) || Translation.tr("Untitled")
                color: root.ink
                elide: Text.ElideRight
                font.family: root.widget.widgetTitleFamily
                font.pixelSize: Math.max(15, Math.round(19 * root.s))
                font.weight: Font.Bold
            }
            InstrumentLabel {
                Layout.fillWidth: true
                visible: text.length > 0
                text: playerBase.effectiveArtist
                color: root.muted
                scaleFactor: root.s
                size: 10
            }
            Item { Layout.fillHeight: true }

            InstrumentScale {
                id: scale
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(9 * root.s)
                divisions: 40
                fraction: playerBase.effectiveLength > 0 ? playerBase.effectivePosition / playerBase.effectiveLength : 0
                ink: root.ink
                accent: root.accent
                animated: root.widget.animationsActive
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Math.round(4 * root.s)
                    enabled: playerBase.effectiveCanSeek && playerBase.effectiveLength > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => playerBase.seek(Math.max(0, Math.min(1, (mouse.x - Math.round(4 * root.s)) / scale.width)) * playerBase.effectiveLength)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(4 * root.s)
                spacing: Math.round(12 * root.s)
                InstrumentField {
                    scaleFactor: root.s
                    label: Translation.tr("Elapsed")
                    value: root.clock(playerBase.effectivePosition)
                    ink: root.ink
                    muted: root.muted
                    family: root.widget.widgetNumbersFamily
                    valueSize: 13
                }
                InstrumentField {
                    scaleFactor: root.s
                    label: Translation.tr("Length")
                    value: playerBase.effectiveLength > 0 ? root.clock(playerBase.effectiveLength) : ""
                    ink: root.ink
                    muted: root.muted
                    family: root.widget.widgetNumbersFamily
                    valueSize: 13
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [
                        { icon: "skip_previous", enabled: playerBase.effectiveCanGoPrevious, action: () => playerBase.previous(), name: Translation.tr("Previous") },
                        { icon: playerBase.effectiveIsPlaying ? "pause" : "play_arrow", enabled: true, action: () => playerBase.togglePlaying(), name: Translation.tr("Play or pause") },
                        { icon: "skip_next", enabled: playerBase.effectiveCanGoNext, action: () => playerBase.next(), name: Translation.tr("Next") }
                    ]
                    RippleButton {
                        required property var modelData
                        Layout.alignment: Qt.AlignBottom
                        implicitWidth: Math.round(28 * root.s)
                        implicitHeight: implicitWidth
                        buttonRadius: Math.round(6 * root.s)
                        enabled: modelData.enabled
                        opacity: enabled ? 1 : 0.4
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(root.accent, 0.14)
                        colRipple: ColorUtils.applyAlpha(root.accent, 0.22)
                        downAction: modelData.action
                        Accessible.name: modelData.name
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: modelData.icon
                            fill: 1
                            iconSize: Math.round(18 * root.s)
                            color: root.ink
                        }
                    }
                }
            }
        }
    }
}
