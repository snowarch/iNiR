import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    required property bool isSink
    required property bool dialogShown
    // By name, so a row keeps its place between openings: PipeWire lists streams in the order they last reshuffled.
    readonly property list<var> appPwNodes: (isSink ? MprisController.mixerAppNodes : Audio.inputAppNodes).slice()
        .sort((a, b) => MprisController.streamDisplayName(a).localeCompare(MprisController.streamDisplayName(b)))
    readonly property list<var> devices: isSink ? Audio.outputDevices : Audio.inputDevices
    readonly property bool hasApps: appPwNodes.length > 0
    readonly property var currentDevice: isSink ? Audio.defaultSink : Audio.source
    spacing: Appearance.sizes.spacingMedium

    // PipeWire reshuffles its nodes when a stream comes or goes, and the app list reads empty for a moment (measured
    // 2026-10-20: two apps, then none, then one, within 20 ms). The empty state waits for the list to stay empty, or it
    // flashes over the rows and fades out.
    property bool emptyShown: !hasApps
    onHasAppsChanged: {
        if (hasApps) {
            emptyShown = false
            emptyWait.stop()
        } else {
            emptyWait.restart()
        }
    }
    Timer {
        id: emptyWait
        interval: 300
        onTriggered: root.emptyShown = !root.hasApps
    }


    onDialogShownChanged: {
        if (!dialogShown && devicePopup.visible)
            devicePopup.close()
    }

    // Device selector at top
    RippleButton {
        id: deviceButton
        Layout.fillWidth: true
        implicitHeight: 48
        
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        buttonRadius: Appearance.rounding.small

        contentItem: RowLayout {
            anchors {
                fill: parent
                leftMargin: Appearance.sizes.spacingMedium
                rightMargin: Appearance.sizes.spacingMedium
            }
            spacing: Appearance.sizes.spacingMedium

            MaterialSymbol {
                text: root.isSink ? "speaker" : "mic"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: Audio.friendlyDeviceName(root.currentDevice) || (root.isSink ? "Select output..." : "Select input...")
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            MaterialSymbol {
                text: devicePopup.visible ? "expand_less" : "expand_more"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
        }

        // Opens on press; a press that just closed it (outside the popup) only closes.
        downAction: () => { if (devicePopup.visible) devicePopup.close(); else if (Date.now() - devicePopup.closedAt > 250) devicePopup.open() }
    }

    Popup {
        id: devicePopup
        property double closedAt: 0
        onClosed: devicePopup.closedAt = Date.now()
        y: deviceButton.y + deviceButton.height + 4
        width: deviceButton.width
        height: Math.min(250, deviceList.contentHeight + 16)
        padding: Appearance.sizes.spacingSmall

        background: Rectangle {
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
                : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface : Appearance.colors.colLayer3
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
        }

        ListView {
            id: deviceList
            anchors.fill: parent
            clip: true
            spacing: 4
            model: root.devices

            delegate: RippleButton {
                required property var modelData
                required property int index
                width: deviceList.width
                implicitHeight: 44

                property bool isSelected: modelData.id === root.currentDevice?.id

                colBackground: isSelected ? Appearance.colors.colPrimaryContainer : "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                buttonRadius: Appearance.rounding.small

                contentItem: RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Appearance.sizes.spacingMedium
                        rightMargin: Appearance.sizes.spacingMedium
                    }
                    spacing: Appearance.sizes.spacingSmall

                    MaterialSymbol {
                        text: isSelected ? "check" : (root.isSink ? "speaker" : "mic")
                        iconSize: Appearance.font.pixelSize.normal
                        color: isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Audio.friendlyDeviceName(modelData)
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                        color: isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                    }
                }

                onClicked: {
                    if (root.isSink) Audio.setDefaultSink(modelData)
                    else Audio.setDefaultSource(modelData)
                    devicePopup.close()
                }
            }
        }
    }

    // Apps list
    StyledListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        clip: true
        spacing: Appearance.sizes.spacingSmall

        model: ScriptModel {
            values: root.appPwNodes
        }
        delegate: VolumeMixerEntry {
            width: ListView.view.width
            required property var modelData
            node: modelData
            capture: !root.isSink
        }

        // Empty state
        StyledText {
            anchors.centerIn: parent
            opacity: root.emptyShown ? 1 : 0
            visible: opacity > 0
            text: root.isSink ? Translation.tr("No apps playing audio") : Translation.tr("No apps using microphone")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }
}
