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
    property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : null
    property bool hasBrightnessMonitor: false
    readonly property bool brightnessEnabled: Config.options?.sidebar?.quickSliders?.showBrightness ?? true
    property real brightnessValue: 0.0
    property real volumeValue: 0.0
    property real sliderSpacing: 10
    property bool compactSurface: false

    function syncBrightness(): void {
        const monitor = root.brightnessMonitor;
        root.hasBrightnessMonitor = monitor !== null && monitor !== undefined;
        const value = Number(monitor?.brightness ?? 0.0);
        root.brightnessValue = Number.isFinite(value) ? value : 0.0;
    }

    function syncVolume(): void {
        const value = Number(Audio.value ?? 0.0);
        root.volumeValue = Number.isFinite(value) ? value : 0.0;
    }

    onBrightnessMonitorChanged: root.syncBrightness()
    Component.onCompleted: {
        root.syncBrightness();
        root.syncVolume();
    }

    Connections {
        target: Brightness
        function onBrightnessChanged(): void { root.syncBrightness(); }
    }

    Connections {
        target: Audio
        function onValueChanged(): void { root.syncVolume(); }
    }

    implicitWidth: contentItem.implicitWidth + root.horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + root.verticalPadding * 2
    radius: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    color: Appearance.zzzEverywhere ? "transparent"
         : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? "transparent"
         : Appearance.colors.colLayer1
    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    border.width: Appearance.zzzEverywhere ? 0 : (root.compactSurface ? 0 : (Appearance.angelEverywhere ? 0 : (Appearance.inirEverywhere ? 1 : 0)))
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    border.color: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    property real verticalPadding: 4
    property real horizontalPadding: 12

    AngelPartialBorder {
        targetRadius: root.radius
        coverage: 0.5
        visible: !root.compactSurface && Appearance.angelEverywhere
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
        spacing: root.sliderSpacing

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: root.brightnessEnabled && root.hasBrightnessMonitor
            sourceComponent: Appearance.zzzEverywhere ? zzzBrightnessSlider : defaultBrightnessSlider
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: Config.options?.sidebar?.quickSliders?.showVolume ?? true
            sourceComponent: Appearance.zzzEverywhere ? zzzVolumeSlider : defaultVolumeSlider
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: Config.options?.sidebar?.quickSliders?.showMic ?? false
            sourceComponent: Appearance.zzzEverywhere ? zzzMicSlider : defaultMicSlider
        }
    }

    component DefaultQuickSlider: StyledSlider {
        id: quickSlider
        required property string materialSymbol
        property real modelValue: 0
        configuration: StyledSlider.Configuration.M
        stopIndicatorValues: []
        scrollable: true

        onModelValueChanged: {
            if (!pressed && !_userInteracting && Math.abs(value - modelValue) > 0.005) {
                value = modelValue
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
                 : Appearance.auroraEverywhere ? Appearance.colors.colOnPrimary
                 : Appearance.colors.colOnPrimary)
                : (Appearance.angelEverywhere ? Appearance.angel.colText
                 : Appearance.inirEverywhere ? Appearance.inir.colOnSecondaryContainer
                 : Appearance.auroraEverywhere ? Appearance.colors.colOnSecondaryContainer
                 : Appearance.colors.colOnSecondaryContainer)
            text: quickSlider.materialSymbol

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            Behavior on anchors.rightMargin {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }

    component ZzzQuickSlider: Slider {
        id: quickSlider
        required property string materialSymbol
        property real modelValue: 0
        property color zzzSignalColor: materialSymbol === "brightness_6" ? Appearance.zzz.tertiary
            : materialSymbol === "mic" ? Appearance.zzz.secondary
            : Appearance.zzz.accent
        property bool _userInteracting: false
        readonly property real effectiveDraggingWidth: width - leftPadding - rightPadding

        Layout.fillWidth: true
        from: 0
        to: 1
        value: modelValue
        implicitHeight: 34
        leftPadding: 30
        rightPadding: 10

        onModelValueChanged: {
            if (!pressed && !_userInteracting && Math.abs(value - modelValue) > 0.005) {
                value = modelValue
            }
        }

        onPressedChanged: {
            if (pressed) {
                _userInteracting = true
            } else {
                interactingReset.restart()
                moved()
            }
        }

        Timer {
            id: interactingReset
            interval: 250
            repeat: false
            onTriggered: quickSlider._userInteracting = false
        }

        MouseArea {
            anchors.fill: parent
            onPressed: mouse => mouse.accepted = false
            cursorShape: quickSlider.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            onWheel: event => {
                quickSlider._userInteracting = true
                interactingReset.restart()
                const step = quickSlider.stepSize > 0 ? quickSlider.stepSize : 0.02
                if (event.angleDelta.y > 0) {
                    quickSlider.value = Math.min(quickSlider.value + step, quickSlider.to)
                } else {
                    quickSlider.value = Math.max(quickSlider.value - step, quickSlider.from)
                }
                quickSlider.moved()
            }
        }

        background: Rectangle {
            radius: Appearance.zzz.controlRadius
            // zzz: transparente (bgless como los quick toggles) — el placa carbon
            // del panel atrás se ve; el icono + segmentos bastan como visual.
            color: "transparent"
            border.width: 0
            border.color: "transparent"

            MaterialSymbol {
                anchors {
                    left: parent.left
                    leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                iconSize: 18
                color: Appearance.zzz.onColor
                text: quickSlider.materialSymbol
            }

            Row {
                anchors {
                    left: parent.left
                    leftMargin: quickSlider.leftPadding
                    right: parent.right
                    rightMargin: quickSlider.rightPadding
                    verticalCenter: parent.verticalCenter
                }
                height: 12
                spacing: 2
                readonly property int segmentCount: Math.max(6, Math.floor(width / 16))
                readonly property real segmentWidth: Math.max(4, (width - (segmentCount - 1) * spacing) / segmentCount)

                Repeater {
                    model: parent.segmentCount
                    Rectangle {
                        required property int index
                        readonly property real threshold: (index + 1) / parent.segmentCount
                        width: parent.segmentWidth
                        height: 12
                        radius: Appearance.zzz.cornerRadius
                        color: quickSlider.visualPosition >= threshold ? quickSlider.zzzSignalColor : Appearance.zzz.metricTrack

                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }

        handle: Rectangle {
            x: quickSlider.leftPadding + (quickSlider.visualPosition * quickSlider.effectiveDraggingWidth) - width / 2
            y: (quickSlider.height - height) / 2
            // Thumb invisible: se conserva el área de arrastre (ancho ~6), pero
            // el "componente chiquito blanco" ya no se ve — la posición la
            // marca el segmento encendido del track. Doctrina zzz: sin thumb.
            width: 14
            height: 22
            radius: 3
            color: "transparent"

            Behavior on width {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }

        StyledToolTip {
            parent: quickSlider.handle
            extraVisibleCondition: quickSlider.pressed
            text: `${Math.round((quickSlider.value / Math.max(0.0001, quickSlider.to)) * 100)}%`
            font {
                family: Appearance.font.family.numbers
                variableAxes: Appearance.font.variableAxes.numbers
                features: { "tnum": 1 }
            }
        }
    }

    Component {
        id: defaultBrightnessSlider
        DefaultQuickSlider {
            materialSymbol: "brightness_6"
            modelValue: root.brightnessValue
            onMoved: root.brightnessMonitor?.setBrightness(value)
        }
    }

    Component {
        id: defaultVolumeSlider
        DefaultQuickSlider {
            materialSymbol: "volume_up"
            modelValue: root.volumeValue
            onMoved: Audio.setSinkVolume(value)
        }
    }

    Component {
        id: defaultMicSlider
        DefaultQuickSlider {
            materialSymbol: "mic"
            modelValue: Audio.micVolume
            onMoved: Audio.setSourceVolume(value)
        }
    }

    Component {
        id: zzzBrightnessSlider
        ZzzQuickSlider {
            materialSymbol: "brightness_6"
            modelValue: root.brightnessValue
            onMoved: root.brightnessMonitor?.setBrightness(value)
        }
    }

    Component {
        id: zzzVolumeSlider
        ZzzQuickSlider {
            materialSymbol: "volume_up"
            modelValue: root.volumeValue
            onMoved: Audio.setSinkVolume(value)
        }
    }

    Component {
        id: zzzMicSlider
        ZzzQuickSlider {
            materialSymbol: "mic"
            modelValue: Audio.micVolume
            onMoved: Audio.setSourceVolume(value)
        }
    }
}
