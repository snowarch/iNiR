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
    readonly property list<var> appPwNodes: isSink ? Audio.outputAppNodes : Audio.inputAppNodes
    readonly property list<var> devices: isSink ? Audio.outputDevices : Audio.inputDevices
    readonly property bool hasApps: appPwNodes.length > 0
    readonly property var currentDevice: isSink ? Audio.defaultSink : Audio.source
    spacing: Appearance.sizes.spacingMedium

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
        }

        // Empty state
        StyledText {
            anchors.centerIn: parent
            opacity: root.appPwNodes.length === 0 ? 1 : 0
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
