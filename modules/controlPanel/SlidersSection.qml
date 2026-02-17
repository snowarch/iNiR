pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: slidersRow.implicitHeight + 12

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

    property var screen: root.QsWindow.window?.screen ?? null
    property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : null

    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : inirEverywhere ? Appearance.inir.colLayer1
         : auroraEverywhere ? Appearance.aurora.colSubSurface
         : Appearance.colors.colLayer1
    border.width: Appearance.angelEverywhere ? 0 : (inirEverywhere ? 1 : 0)
    border.color: Appearance.angelEverywhere ? "transparent"
        : inirEverywhere ? Appearance.inir.colBorder : "transparent"

    AngelPartialBorder { targetRadius: parent.radius; coverage: 0.45 }

    RowLayout {
        id: slidersRow
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        // Brightness
        Loader {
            Layout.fillWidth: true
            visible: active
            active: (Config.options?.sidebar?.quickSliders?.showBrightness ?? true) && !!root.brightnessMonitor
            sourceComponent: MiniSlider {
                icon: "brightness_6"
                value: root.brightnessMonitor?.brightness ?? 0
                onMoved: (val) => root.brightnessMonitor?.setBrightness(val)
            }
        }

        // Volume
        Loader {
            Layout.fillWidth: true
            visible: active
            active: Config.options?.sidebar?.quickSliders?.showVolume ?? true
            sourceComponent: MiniSlider {
                icon: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                value: Audio.sink?.audio?.volume ?? 0
                onMoved: (val) => { if (Audio.sink?.audio) Audio.sink.audio.volume = val }
                onIconClicked: Audio.sink?.audio?.toggleMute()
            }
        }

        // Mic
        Loader {
            Layout.fillWidth: true
            visible: active
            active: Config.options?.sidebar?.quickSliders?.showMic ?? false
            sourceComponent: MiniSlider {
                icon: Audio.source?.audio?.muted ? "mic_off" : "mic"
                value: Audio.source?.audio?.volume ?? 0
                onMoved: (val) => { if (Audio.source?.audio) Audio.source.audio.volume = val }
                onIconClicked: Audio.source?.audio?.toggleMute()
            }
        }
    }

    component MiniSlider: RowLayout {
        id: miniSlider
        property string icon
        property real value: 0
        signal moved(real val)
        signal iconClicked()

        spacing: 4

        RippleButton {
            implicitWidth: 28
            implicitHeight: 28
            buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
            colBackground: "transparent"
            colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                              : root.inirEverywhere ? Appearance.inir.colLayer2Hover 
                              : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                              : Appearance.colors.colLayer2Hover
            onClicked: miniSlider.iconClicked()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: miniSlider.icon
                iconSize: 16
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                     : root.inirEverywhere ? Appearance.inir.colText 
                     : root.auroraEverywhere ? Appearance.m3colors.m3onSurface
                     : Appearance.colors.colOnLayer1
            }
        }

        StyledSlider {
            id: slider
            Layout.fillWidth: true
            configuration: StyledSlider.Configuration.M
            stopIndicatorValues: []
            scrollable: true
            value: miniSlider.value
            
            onMoved: miniSlider.moved(value)
            
            Binding {
                target: slider
                property: "value"
                value: miniSlider.value
                when: !slider.pressed && !slider._userInteracting
                restoreMode: Binding.RestoreNone
            }
        }
    }
}
