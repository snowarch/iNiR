import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

Rectangle {
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    implicitWidth: contentItem.implicitWidth + root.horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + root.verticalPadding * 2

    readonly property bool cardStyle: Config.options?.sidebar?.cardStyle ?? false

    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: cardStyle ? "transparent"
        :(Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1)

    border.width: Appearance.inirEverywhere?1:0
    border.color: Appearance.inir.colBorder

    property real verticalPadding: 4
    property real horizontalPadding: 12

    Column {
        id: contentItem
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }

        Loader {
            anchors {
                left: parent.left
                right: parent.right
            }
            visible: active
            active: Config.options.sidebar.quickSliders.showBrightness
            sourceComponent: QuickSlider {
                materialSymbol: "brightness_6"
                value: root.brightnessMonitor.brightness
                onMoved: {
                    root.brightnessMonitor.setBrightness(value)
                }
            }
        }

        Loader {
            anchors {
                left: parent.left
                right: parent.right
            }
            visible: active
            active: Config.options.sidebar.quickSliders.showVolume
            sourceComponent: QuickSlider {
                materialSymbol: "volume_up"
                value: Audio.sink.audio.volume
                onMoved: {
                    Audio.sink.audio.volume = value
                }
            }
        }

        Loader {
            anchors {
                left: parent.left
                right: parent.right
            }
            visible: active
            active: Config.options.sidebar.quickSliders.showMic
            sourceComponent: QuickSlider {
                materialSymbol: "mic"
                value: Audio.source.audio.volume
                onMoved: {
                    Audio.source.audio.volume = value
                }
            }
        }
    }

    component QuickSlider: StyledSlider {
        id: quickSlider
        required property string materialSymbol
        configuration: StyledSlider.Configuration.M
        stopIndicatorValues: []
        scrollable: true

        MaterialSymbol {
            id: icon
            property bool nearFull: quickSlider.value >= 0.9
            anchors {
                verticalCenter: parent.verticalCenter
                right: nearFull ? quickSlider.handle.right : parent.right
                rightMargin: quickSlider.nearFull ? 14 : 8
            }
            iconSize: 20
            color: nearFull
                ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                 : Appearance.auroraEverywhere ? Appearance.m3colors.m3onPrimary
                 : Appearance.colors.colOnPrimary)
                : (Appearance.inirEverywhere ? Appearance.inir.colOnSecondaryContainer
                 : Appearance.auroraEverywhere ? Appearance.m3colors.m3onSecondaryContainer
                 : Appearance.colors.colOnSecondaryContainer)
            text: quickSlider.materialSymbol

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
            Behavior on anchors.rightMargin {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

        }
    }
}
