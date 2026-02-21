import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Wayland

WindowDialog {
    id: root
    property var screen: root.QsWindow.window?.screen
    // Brightness monitor may be unavailable on some outputs; guard access.
    property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : null
    backgroundHeight: 680

    WindowDialogTitle {
        text: Translation.tr("Eye protection")
    }
    
    WindowDialogSectionHeader {
        text: Translation.tr("Night Light")
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    Column {
        id: nightLightColumn
        Layout.topMargin: -16
        Layout.fillWidth: true

        ConfigSwitch {
            anchors {
                left: parent.left
                right: parent.right
            }
            iconSize: Appearance.font.pixelSize.larger
            buttonIcon: "lightbulb"
            text: Translation.tr("Enable now")
            checked: Hyprsunset.active
            onCheckedChanged: {
                Hyprsunset.toggle(checked)
            }
        }

        ConfigSwitch {
            anchors {
                left: parent.left
                right: parent.right
            }
            iconSize: Appearance.font.pixelSize.larger
            buttonIcon: "night_sight_auto"
            text: Translation.tr("Automatic")
            checked: Config.options?.light?.night?.automatic ?? false
            onCheckedChanged: {
                Config.setNestedValue("light.night.automatic", checked);
            }
        }

        // Schedule settings (only visible when automatic is enabled)
        Column {
            anchors {
                left: parent.left
                right: parent.right
            }
            visible: Config.options?.light?.night?.automatic ?? false
            opacity: visible ? 1 : 0
            spacing: 4

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            ConfigTimeInput {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                icon: "wb_twilight"
                text: Translation.tr("Turn on at")
                value: Config.options?.light?.night?.from ?? "19:00"
                onTimeChanged: (newTime) => {
                    Config.setNestedValue("light.night.from", newTime);
                }
            }

            ConfigTimeInput {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                icon: "wb_sunny"
                text: Translation.tr("Turn off at")
                value: Config.options?.light?.night?.to ?? "06:30"
                onTimeChanged: (newTime) => {
                    Config.setNestedValue("light.night.to", newTime);
                }
            }
        }

        WindowDialogSlider {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 4
                rightMargin: 4
            }
            text: Translation.tr("Intensity")
            from: 6500
            to: 1200
            stopIndicatorValues: [5000, to]
            value: Config.options?.light?.night?.colorTemperature ?? 4500
            onMoved: Config.setNestedValue("light.night.colorTemperature", value)
            tooltipContent: `${Math.round(value)}K`
        }
    }

    WindowDialogSectionHeader {
        text: Translation.tr("Anti-flashbang (experimental)")
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    Column {
        id: antiFlashbangColumn
        Layout.topMargin: -16
        Layout.fillWidth: true

        ConfigSwitch {
            anchors {
                left: parent.left
                right: parent.right
            }
            iconSize: Appearance.font.pixelSize.larger
            buttonIcon: "flash_off"
            text: Translation.tr("Enable")
            checked: Config.options?.light?.antiFlashbang?.enable ?? false
            onCheckedChanged: {
                Config.setNestedValue("light.antiFlashbang.enable", checked);
            }
            StyledToolTip {
                text: Translation.tr("Example use case: eroge on one workspace, dark Discord window on another")
            }
        }
    }

    WindowDialogSectionHeader {
        text: Translation.tr("Brightness")
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    Column {
        id: brightnessColumn
        Layout.topMargin: -16
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !!root.brightnessMonitor

        WindowDialogSlider {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 4
                rightMargin: 4
            }
            // text: Translation.tr("Brightness")
            value: root.brightnessMonitor?.brightness ?? 0
            onMoved: root.brightnessMonitor?.setBrightness(value)
        }
    }
    
    WindowDialogButtonRow {
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
