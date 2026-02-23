import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

ColumnLayout {
    id: root
    required property bool isSink
    readonly property list<var> appPwNodes: isSink ? Audio.outputAppNodes : Audio.inputAppNodes
    readonly property list<var> devices: isSink ? Audio.outputDevices : Audio.inputDevices
    readonly property bool hasApps: appPwNodes.length > 0
    readonly property var currentDevice: isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
    spacing: Appearance.sizes.spacingMedium

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

        onClicked: devicePopup.visible ? devicePopup.close() : devicePopup.open()
    }

    Popup {
        id: devicePopup
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
                        color: isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.m3colors.m3onSurface
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
        }

        // Empty state
        StyledText {
            anchors.centerIn: parent
            visible: root.appPwNodes.length === 0
            text: root.isSink ? Translation.tr("No apps playing audio") : Translation.tr("No apps using microphone")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }
}
