import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: root

    property var screen: root.QsWindow.window?.screen
    // Brightness monitor may be undefined (e.g. Niri without matching monitor); guard it.
    property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : null

    implicitWidth: contentItem.implicitWidth + root.horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + root.verticalPadding * 2
    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? "transparent" 
         : Appearance.colors.colLayer1
    border.width: Appearance.angelEverywhere ? 0 : (Appearance.inirEverywhere ? 1 : 0)
    border.color: Appearance.angelEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    property real verticalPadding: 4
    property real horizontalPadding: 12

    AngelPartialBorder {
        targetRadius: root.radius
        coverage: 0.5
    }

    RowLayout {
        id: contentItem
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }
        spacing: 10

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: (Config.options?.sidebar?.quickSliders?.showBrightness ?? true) && !!root.brightnessMonitor
            sourceComponent: QuickSlider {
                materialSymbol: "brightness_6"
                modelValue: root.brightnessMonitor?.brightness ?? 0
                onMoved: root.brightnessMonitor?.setBrightness(value)
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: Config.options?.sidebar?.quickSliders?.showVolume ?? true
            sourceComponent: QuickSlider {
                materialSymbol: "volume_up"
                modelValue: Audio.sink?.audio?.volume ?? 0
                onMoved: {
                    if (Audio.sink?.audio)
                        Audio.sink.audio.volume = value
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: Config.options?.sidebar?.quickSliders?.showMic ?? false
            sourceComponent: QuickSlider {
                materialSymbol: "mic"
                modelValue: Audio.source?.audio?.volume ?? 0
                onMoved: {
                    if (Audio.source?.audio)
                        Audio.source.audio.volume = value
                }
            }
        }
    }

    component QuickSlider: StyledSlider { 
        id: quickSlider
        required property string materialSymbol
        property real modelValue: 0
        configuration: StyledSlider.Configuration.M
        stopIndicatorValues: []
        scrollable: true

        // Sync from model only when not interacting, with threshold to avoid micro-jumps
        onModelValueChanged: {
            if (!pressed && !_userInteracting) {
                if (Math.abs(value - modelValue) > 0.005) {
                    value = modelValue
                }
            }
        }
        
        MaterialSymbol {
            id: icon
            property bool nearFull: quickSlider.value >= 0.9
            anchors {
                verticalCenter: parent.verticalCenter
                right: nearFull ? quickSlider.handle.right : parent.right
                rightMargin: nearFull ? 14 : 8
            }
            iconSize: 20
            color: nearFull
                ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                 : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                 : Appearance.auroraEverywhere ? Appearance.m3colors.m3onPrimary
                 : Appearance.colors.colOnPrimary)
                : (Appearance.angelEverywhere ? Appearance.angel.colText
                 : Appearance.inirEverywhere ? Appearance.inir.colOnSecondaryContainer
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
