pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas

Rectangle {
    id: root

    property real padding: 8

    opacity: GlobalStates.overlayOpen ? 1 : 0
    implicitWidth: contentRow.implicitWidth + (padding * 2)
    implicitHeight: contentRow.implicitHeight + (padding * 2)
    color: Appearance.angelEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.m3colors.m3surfaceContainer
    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.large
    border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.colors.colOutlineVariant
    border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
    clip: true

    layer.enabled: Appearance.angelEverywhere
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    // Wallpaper blur for angel style
    Image {
        id: taskbarBlurWallpaper
        x: -root.x
        y: -root.y
        width: Quickshell.screens[0]?.width ?? 1920
        height: Quickshell.screens[0]?.height ?? 1080
        visible: Appearance.angelEverywhere
        source: Wallpapers.effectiveWallpaperUrl
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        layer.enabled: Appearance.effectsEnabled
        layer.effect: MultiEffect {
            source: taskbarBlurWallpaper
            anchors.fill: source
            saturation: Appearance.angel.blurSaturation * Appearance.angel.colorStrength
            blurEnabled: Appearance.effectsEnabled
            blurMax: 100
            blur: Appearance.effectsEnabled ? Appearance.angel.blurIntensity : 0
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: Appearance.angelEverywhere
        color: ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
    }

    AngelPartialBorder {
        targetRadius: root.radius
        visible: Appearance.angelEverywhere
    }

    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    RowLayout {
        id: contentRow
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 6

        Row {
            spacing: 4
            Repeater {
                model: ScriptModel {
                    values: OverlayContext.availableWidgets
                }
                delegate: WidgetButton {
                    required property var modelData
                    identifier: modelData.identifier
                    materialSymbol: modelData.materialSymbol
                }
            }
        }

        Separator {}
        TimeWidget {}
        Separator {
            visible: Battery.available
        }
        BatteryWidget {
            visible: Battery.available
        }
    }

    component Separator: Rectangle {
        implicitWidth: 1
        color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
            : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
            : Appearance.colors.colOutlineVariant
        Layout.fillHeight: true
        Layout.topMargin: 10
        Layout.bottomMargin: 10
    }

    component TimeWidget: StyledText {
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 8
        Layout.rightMargin: 6

        text: DateTime.time
        color: Appearance.colors.colOnSurface
        font {
            family: Appearance.font.family.numbers
            variableAxes: Appearance.font.variableAxes.numbers
            pixelSize: 22
        }
    }
    
    component BatteryWidget: Row {
        id: batteryWidget
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        spacing: 2
        property color colText: Battery.isLowAndNotCharging ? Appearance.colors.colError : Appearance.colors.colOnSurface

        MaterialSymbol {
            id: boltIcon
            anchors.verticalCenter: parent.verticalCenter
            fill: 1
            text: Battery.isCharging ? "bolt" : "battery_android_full"
            color: batteryWidget.colText
            iconSize: 24
            animateChange: true
        }
        
        StyledText {
            id: batteryText
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Battery.percentage * 100) + "%"
            color: batteryWidget.colText
            font {
                family: Appearance.font.family.numbers
                variableAxes: Appearance.font.variableAxes.numbers
                pixelSize: 18
            }
        }
    }

    component WidgetButton: RippleButton {
        id: widgetButton
        required property string identifier
        required property string materialSymbol

        Layout.alignment: Qt.AlignVCenter

        toggled: Persistent.states.overlay.open.includes(identifier)
        onClicked: {
            if (widgetButton.toggled) {
                Persistent.states.overlay.open = Persistent.states.overlay.open.filter(type => type !== identifier);
            } else {
                Persistent.states.overlay.open.push(identifier);
            }
        }
        implicitWidth: implicitHeight

        colBackgroundToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
            : Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.colors.colSecondaryContainerHover
        colRippleToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.colors.colSecondaryContainerActive

        buttonRadius: root.radius - (root.height - height) / 2

        contentItem: Item {
            anchors.centerIn: parent
            implicitWidth: 32
            implicitHeight: 32
            MaterialSymbol {
                id: iconWidget
                anchors.centerIn: parent
                iconSize: 24
                text: widgetButton.identifier === "recorder" && RecorderStatus.isRecording ? "radio_button_checked" : widgetButton.materialSymbol
                color: widgetButton.identifier === "recorder" && RecorderStatus.isRecording
                        ? Appearance.colors.colError
                        : (widgetButton.toggled
                            ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.colors.colOnSecondaryContainer)
                            : (Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnSurfaceVariant))
            }
        }

        StyledToolTip {
            text: widgetButton.identifier === "crosshair" ? Translation.tr("Crosshair overlay")
                  : widgetButton.identifier === "fpsLimiter" ? Translation.tr("FPS limiter")
                  : widgetButton.identifier === "floatingImage" ? Translation.tr("Floating image")
                  : widgetButton.identifier === "recorder" ? Translation.tr("Recorder")
                  : widgetButton.identifier === "resources" ? Translation.tr("Resources")
                  : widgetButton.identifier === "notes" ? Translation.tr("Notes")
                  : widgetButton.identifier === "discord" ? Translation.tr("Discord control")
                  : widgetButton.identifier === "volumeMixer" ? Translation.tr("Volume mixer")
                  : widgetButton.identifier
        }
    }
}
