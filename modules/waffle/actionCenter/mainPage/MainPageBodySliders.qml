import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter
import qs.modules.waffle.actionCenter.volumeControl

ColumnLayout {
    id: root
    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    spacing: 12

    RowLayout {
        spacing: 4

        WPanelIconButton {
            color: colBackground
            property real animationValue: root.brightnessMonitor?.brightness ?? 0
            rotation: animationValue * 180
            scale: 0.8 + animationValue * 0.2
            iconName: "weather-sunny"

            Behavior on animationValue {
                animation: NumberAnimation { duration: Looks.transition.enabled ? 800 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.emphasize }
            }
        }
        
        WSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            property real modelValue: root.brightnessMonitor?.brightness ?? 0

            Binding {
                target: brightnessSlider
                property: "value"
                value: brightnessSlider.modelValue
                when: !brightnessSlider.pressed && !brightnessSlider._userInteracting
            }
            scrollable: true
            tooltipContent: `${Math.round(value * 100)}%`
            onMoved: root.brightnessMonitor?.setBrightness(value)
        }

        WPanelIconButton {
            opacity: 0
        }
    }
    
    RowLayout {
        spacing: 4

        WPanelIconButton {
            iconName: WIcons.volumeIcon ?? "speaker"
            onClicked: Audio.toggleMute();
        }
        
        WSlider {
            id: volumeSlider
            Layout.fillWidth: true
            property real modelValue: Audio.sink?.audio?.volume ?? 0
            to: 1.5

            Binding {
                target: volumeSlider
                property: "value"
                value: volumeSlider.modelValue
                when: !volumeSlider.pressed && !volumeSlider._userInteracting
            }
            scrollable: true
            onMoved: Audio.setSinkVolume(value)
        }

        WPanelIconButton {
            Component {
                id: volumeControlComp
                VolumeControl {}
            }
            onClicked: {
                if (ActionCenterContext.stackView) ActionCenterContext.stackView.push(volumeControlComp)
            }
            contentItem: Item {
                anchors.centerIn: parent
                Row {
                    anchors.centerIn: parent
                    spacing: -1
                    FluentIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 18
                        icon: "options"
                    }
                    FluentIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 12
                        icon: "chevron-right"
                    }
                }
            }
        }
    }

}
