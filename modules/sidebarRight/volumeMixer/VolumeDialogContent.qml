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
    spacing: 16

    // Device selector button
    RippleButton {
        id: deviceButton
        Layout.fillWidth: true
        Layout.topMargin: 8
        implicitHeight: 48
        
        colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer2
        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
        buttonRadius: Appearance.rounding.normal

        contentItem: RowLayout {
            anchors {
                fill: parent
                leftMargin: 16
                rightMargin: 16
            }
            spacing: 12

            MaterialSymbol {
                text: root.isSink ? "speaker" : "mic"
                iconSize: 24
                color: Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: Audio.friendlyDeviceName(root.currentDevice) || (root.isSink ? Translation.tr("Select output...") : Translation.tr("Select input..."))
                font.pixelSize: Appearance.font.pixelSize.normal
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

    // Device selection popup
    Popup {
        id: devicePopup
        y: deviceButton.y + deviceButton.height + 4
        width: deviceButton.width
        height: Math.min(250, deviceList.contentHeight + 16)
        padding: 8

        background: Rectangle {
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
                : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface : Appearance.colors.colLayer2
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.normal
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : Appearance.colors.colOutlineVariant
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
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 8

                    MaterialSymbol {
                        text: isSelected ? "check" : (root.isSink ? "speaker" : "mic")
                        iconSize: Appearance.font.pixelSize.normal
                        color: isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Audio.friendlyDeviceName(modelData)
                        font.pixelSize: Appearance.font.pixelSize.normal
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
    DialogSectionListView {
        Layout.fillHeight: true
        topMargin: 14

        model: ScriptModel {
            values: root.appPwNodes
        }
        delegate: VolumeMixerEntry {
            anchors {
                left: parent?.left
                right: parent?.right
            }
            required property var modelData
            node: modelData
        }
        PagePlaceholder {
            icon: "widgets"
            title: Translation.tr("No applications")
            shown: !root.hasApps
            shape: MaterialShape.Shape.Cookie7Sided
        }
    }

    component DialogSectionListView: StyledListView {
        Layout.fillWidth: true
        Layout.topMargin: -22
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
        topMargin: 12
        bottomMargin: 12
        leftMargin: 20
        rightMargin: 20

        clip: true
        spacing: 4
        animateAppearance: false
    }
}
