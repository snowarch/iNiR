pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.background.widgets

// Controls on the desktop:
//   - iRiS and Prism draw their own faces
//   - iNstrument design draws ControlsInstrument (patch panel)
//   - Material draws three expressive styles ("shapes", "row", "tiles") across three toggle sets ("connect", "evening", "sound")
AbstractBackgroundWidget {
    id: root

    configEntryName: "controls"
    needsColText: true
    widgetSurfaceEnabled: root.controlsStyle !== "shapes" && !root.instrument
    resizeMinWidth: 160
    resizeMinHeight: 110

    readonly property string controlsStyle: String(root._readConfigKey("style") ?? "shapes")
    readonly property string toggleSet: String(root._readConfigKey("set") ?? "connect")
    readonly property bool instrument: root.widgetSharedDesign === "instrument"
        || root.widgetSharedDesign === "readout"
        || root.controlsStyle === "instrument"

    readonly property var toggleItems: {
        if (root.toggleSet === "evening") {
            return [
                {
                    id: "night",
                    label: Translation.tr("Night light"),
                    sub: Hyprsunset.active ? Translation.tr("On") : Translation.tr("Off"),
                    icon: "nightlight",
                    active: Hyprsunset.active,
                    available: true,
                    shape: MaterialShape.Shape.Cookie9Sided,
                    role: root.widgetPrimaryRole,
                    action: () => Hyprsunset.toggle()
                },
                {
                    id: "dnd",
                    label: Translation.tr("Focus"),
                    sub: Notifications.manualDndActive ? Translation.tr("Quiet") : Translation.tr("Off"),
                    icon: Notifications.manualDndActive ? "do_not_disturb_on" : "notifications",
                    active: Notifications.manualDndActive,
                    available: true,
                    shape: MaterialShape.Shape.Clover4Leaf,
                    role: root.widgetSecondaryRole,
                    action: () => Notifications.toggleSilent()
                },
                {
                    id: "dark",
                    label: Translation.tr("Dark mode"),
                    sub: Appearance.m3colors.darkmode ? Translation.tr("On") : Translation.tr("Light"),
                    icon: Appearance.m3colors.darkmode ? "dark_mode" : "light_mode",
                    active: Appearance.m3colors.darkmode,
                    available: true,
                    shape: MaterialShape.Shape.Sunny,
                    role: root.widgetTertiaryRole,
                    action: () => Appearance.toggleDarkMode()
                },
                {
                    id: "awake",
                    label: Translation.tr("Keep awake"),
                    sub: Idle.inhibit ? Translation.tr("Active") : Translation.tr("Off"),
                    icon: "coffee",
                    active: Idle.inhibit,
                    available: true,
                    shape: MaterialShape.Shape.Flower,
                    role: root.widgetPrimaryRole,
                    action: () => Idle.toggleInhibit()
                }
            ]
        }
        if (root.toggleSet === "sound") {
            const sinkMuted = Audio.sink?.audio?.muted ?? false
            const micActive = Audio.source !== null && !Audio.micMuted
            return [
                {
                    id: "mute",
                    label: Translation.tr("Output"),
                    sub: sinkMuted ? Translation.tr("Muted") : Math.round(Math.min(1, Audio.value ?? 0) * 100) + "%",
                    icon: sinkMuted ? "volume_off" : "volume_up",
                    active: !sinkMuted,
                    available: Audio.sink !== null,
                    shape: MaterialShape.Shape.Cookie9Sided,
                    role: root.widgetPrimaryRole,
                    action: () => Audio.toggleMute()
                },
                {
                    id: "mic",
                    label: Translation.tr("Microphone"),
                    sub: micActive ? Translation.tr("Live") : Translation.tr("Muted"),
                    icon: micActive ? "mic" : "mic_off",
                    active: micActive,
                    available: Audio.source !== null,
                    shape: MaterialShape.Shape.Clover4Leaf,
                    role: root.widgetSecondaryRole,
                    action: () => Audio.toggleMicMute()
                },
                {
                    id: "dnd",
                    label: Translation.tr("Focus"),
                    sub: Notifications.manualDndActive ? Translation.tr("Quiet") : Translation.tr("Off"),
                    icon: Notifications.manualDndActive ? "do_not_disturb_on" : "notifications",
                    active: Notifications.manualDndActive,
                    available: true,
                    shape: MaterialShape.Shape.Sunny,
                    role: root.widgetTertiaryRole,
                    action: () => Notifications.toggleSilent()
                },
                {
                    id: "gamemode",
                    label: Translation.tr("Game mode"),
                    sub: GameMode.active ? Translation.tr("Active") : Translation.tr("Off"),
                    icon: "sports_esports",
                    active: GameMode.active,
                    available: true,
                    shape: MaterialShape.Shape.Flower,
                    role: root.widgetPrimaryRole,
                    action: () => GameMode.toggle()
                }
            ]
        }
        const wifiOn = Network.ethernet || Network.wifiEnabled
        const btSummary = BluetoothStatus.activeDeviceSummary() || ""
        return [
            {
                id: "wifi",
                label: Network.ethernet ? Translation.tr("Ethernet") : (Network.networkName || Translation.tr("Wi-Fi")),
                sub: Network.ethernet ? Translation.tr("Wired") : (Network.wifiEnabled ? (Network.networkName ? Translation.tr("Connected") : Translation.tr("On")) : Translation.tr("Off")),
                icon: Network.ethernet ? "lan" : (Network.wifiEnabled ? "wifi" : "wifi_off"),
                active: wifiOn,
                available: true,
                shape: MaterialShape.Shape.Cookie9Sided,
                role: root.widgetPrimaryRole,
                action: () => Network.toggleWifi()
            },
            {
                id: "bt",
                label: btSummary.length > 0 ? btSummary : Translation.tr("Bluetooth"),
                sub: btSummary.length > 0 ? Translation.tr("Connected") : (BluetoothStatus.enabled ? Translation.tr("On") : Translation.tr("Off")),
                icon: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled",
                active: BluetoothStatus.enabled,
                available: BluetoothStatus.available,
                shape: MaterialShape.Shape.Clover4Leaf,
                role: root.widgetSecondaryRole,
                action: () => { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
            },
            {
                id: "dnd",
                label: Translation.tr("Focus"),
                sub: Notifications.manualDndActive ? Translation.tr("Quiet") : Translation.tr("Off"),
                icon: Notifications.manualDndActive ? "do_not_disturb_on" : "notifications",
                active: Notifications.manualDndActive,
                available: true,
                shape: MaterialShape.Shape.Sunny,
                role: root.widgetTertiaryRole,
                action: () => Notifications.toggleSilent()
            },
            {
                id: "night",
                label: Translation.tr("Night light"),
                sub: Hyprsunset.active ? Translation.tr("On") : Translation.tr("Off"),
                icon: "nightlight",
                active: Hyprsunset.active,
                available: true,
                shape: MaterialShape.Shape.Flower,
                role: root.widgetPrimaryRole,
                action: () => Hyprsunset.toggle()
            }
        ]
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced && root.instrument
        sourceComponent: ControlsInstrument { widget: root }
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced && !root.instrument
        sourceComponent: Item {
            id: materialFace

            WidgetSurface {
                widget: root
                anchors.fill: parent
                shown: !root.familyFaced && !root.instrument
                    && (root.controlsStyle !== "shapes" || root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
                surfaceColor: root.widgetInk
            }

            // 1. "shapes": 2x2 grid of expressive MaterialShapes that morph from Circle to their active polygon
            Grid {
                id: shapesGrid
                visible: root.controlsStyle === "shapes"
                anchors.centerIn: parent
                columns: 2
                spacing: Math.round(10 * root.scaleFactor)
                readonly property real cellSize: Math.max(44, Math.floor(Math.min(
                    parent.width - Math.round(28 * root.scaleFactor),
                    parent.height - Math.round(28 * root.scaleFactor)) - spacing) / 2)

                Repeater {
                    model: root.controlsStyle === "shapes" ? root.toggleItems : []

                    Item {
                        id: shapeToggle
                        required property var modelData
                        width: shapesGrid.cellSize
                        height: shapesGrid.cellSize
                        opacity: shapeToggle.modelData.available ? 1 : 0.45

                        readonly property var mark: root.widgetMark(shapeToggle.modelData.role)
                        readonly property color activeFill: root.widgetHasSurface
                            ? root.widgetSemanticColor(shapeToggle.modelData.role)
                            : shapeToggle.mark.fill
                        readonly property color activeInk: root.widgetHasSurface
                            ? root.widgetSemanticOnColor(shapeToggle.modelData.role)
                            : shapeToggle.mark.ink
                        readonly property color offFill: root.widgetHasSurface
                            ? ColorUtils.applyAlpha(root.widgetInk, shapeTap.containsMouse ? 0.16 : 0.10)
                            : ColorUtils.applyAlpha(root.widgetPlateColor, shapeTap.containsMouse ? 0.88 : 0.76)

                        MaterialShape {
                            anchors.fill: parent
                            shape: shapeToggle.modelData.active ? shapeToggle.modelData.shape : MaterialShape.Shape.Circle
                            color: shapeToggle.modelData.active ? shapeToggle.activeFill : shapeToggle.offFill
                            rotation: shapeToggle.modelData.active ? 18 : 0
                            scale: shapeTap.pressed ? 0.90 : (shapeTap.containsMouse ? 1.05 : 1.0)

                            Behavior on color {
                                enabled: root.animationsActive
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                            Behavior on rotation {
                                enabled: root.animationsActive
                                NumberAnimation {
                                    duration: Appearance.animation.elementMove.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                                }
                            }
                            Behavior on scale {
                                enabled: root.animationsActive
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                                }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                rotation: -parent.rotation
                                text: shapeToggle.modelData.icon
                                fill: shapeToggle.modelData.active ? 1 : 0
                                iconSize: Math.round(shapeToggle.width * 0.36)
                                color: shapeToggle.modelData.active ? shapeToggle.activeInk : root.widgetInk
                            }
                        }

                        MouseArea {
                            id: shapeTap
                            anchors.fill: parent
                            enabled: shapeToggle.modelData.available
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shapeToggle.modelData.action()
                        }

                        StyledToolTip {
                            extraVisibleCondition: shapeTap.containsMouse
                            text: `${shapeToggle.modelData.label} · ${shapeToggle.modelData.sub}`
                        }
                    }
                }
            }

            // 2. "row": 4 buttons in a horizontal row, morphing circle -> rounded square when active
            Row {
                id: rowStrip
                visible: root.controlsStyle === "row"
                anchors.centerIn: parent
                spacing: Math.round(10 * root.scaleFactor)
                readonly property real btnSize: Math.max(36, Math.min(
                    parent.height - Math.round(24 * root.scaleFactor),
                    Math.floor((parent.width - Math.round(28 * root.scaleFactor) - spacing * 3) / 4)))

                Repeater {
                    model: root.controlsStyle === "row" ? root.toggleItems : []

                    Rectangle {
                        id: rowBtn
                        required property var modelData
                        width: rowStrip.btnSize
                        height: rowStrip.btnSize
                        radius: rowBtn.modelData.active ? Math.round(14 * root.scaleFactor) : width / 2
                        opacity: rowBtn.modelData.available ? 1 : 0.45
                        color: rowBtn.modelData.active
                            ? root.widgetSemanticColor(rowBtn.modelData.role)
                            : ColorUtils.applyAlpha(root.widgetInk, rowTap.containsMouse ? 0.16 : 0.10)
                        scale: rowTap.pressed ? 0.90 : (rowTap.containsMouse ? 1.05 : 1.0)

                        Behavior on radius {
                            enabled: root.animationsActive
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                            }
                        }
                        Behavior on color {
                            enabled: root.animationsActive
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }
                        Behavior on scale {
                            enabled: root.animationsActive
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: rowBtn.modelData.icon
                            fill: rowBtn.modelData.active ? 1 : 0
                            iconSize: Math.round(rowBtn.width * 0.44)
                            color: rowBtn.modelData.active
                                ? root.widgetSemanticOnColor(rowBtn.modelData.role)
                                : root.widgetInk
                        }

                        MouseArea {
                            id: rowTap
                            anchors.fill: parent
                            enabled: rowBtn.modelData.available
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rowBtn.modelData.action()
                        }

                        StyledToolTip {
                            extraVisibleCondition: rowTap.containsMouse
                            text: `${rowBtn.modelData.label} · ${rowBtn.modelData.sub}`
                        }
                    }
                }
            }

            // 3. "tiles": 2x2 Material 3 quick-setting tiles with icon, label, and status
            GridLayout {
                id: tilesGrid
                visible: root.controlsStyle === "tiles"
                anchors.fill: parent
                anchors.margins: Math.round(12 * root.scaleFactor)
                columns: 2
                columnSpacing: Math.round(8 * root.scaleFactor)
                rowSpacing: Math.round(8 * root.scaleFactor)

                Repeater {
                    model: root.controlsStyle === "tiles" ? root.toggleItems : []

                    Rectangle {
                        id: tileCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 1
                        opacity: tileCard.modelData.available ? 1 : 0.45
                        radius: tileCard.modelData.active
                            ? Math.min(root.widgetCardRadius, Math.round(16 * root.scaleFactor))
                            : height / 2
                        color: tileCard.modelData.active
                            ? root.widgetSemanticContainer(tileCard.modelData.role)
                            : ColorUtils.applyAlpha(root.widgetInk, tileTap.containsMouse ? 0.14 : 0.08)
                        scale: tileTap.pressed ? 0.96 : 1.0

                        readonly property color fg: tileCard.modelData.active
                            ? root.widgetSemanticOnContainer(tileCard.modelData.role)
                            : root.widgetInk
                        readonly property color subFg: tileCard.modelData.active
                            ? ColorUtils.applyAlpha(tileCard.fg, 0.78)
                            : root.widgetInkMuted

                        Behavior on radius {
                            enabled: root.animationsActive
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                            }
                        }
                        Behavior on color {
                            enabled: root.animationsActive
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }
                        Behavior on scale {
                            enabled: root.animationsActive
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(12 * root.scaleFactor)
                            anchors.rightMargin: Math.round(10 * root.scaleFactor)
                            spacing: Math.round(8 * root.scaleFactor)

                            MaterialSymbol {
                                text: tileCard.modelData.icon
                                fill: tileCard.modelData.active ? 1 : 0
                                iconSize: Math.round((root.isSmall ? 18 : 20) * root.scaleFactor)
                                color: tileCard.fg
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: tileCard.modelData.label
                                    color: tileCard.fg
                                    font.family: root.widgetBodyFamily
                                    font.pixelSize: Math.round((root.isSmall ? 11 : 12.5) * root.scaleFactor)
                                    font.weight: Font.DemiBold
                                }

                                StyledText {
                                    visible: !root.isSmall && tileCard.height >= Math.round(44 * root.scaleFactor)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: tileCard.modelData.sub
                                    color: tileCard.subFg
                                    font.family: root.widgetBodyFamily
                                    font.pixelSize: Math.round(10.5 * root.scaleFactor)
                                }
                            }
                        }

                        MouseArea {
                            id: tileTap
                            anchors.fill: parent
                            enabled: tileCard.modelData.available
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tileCard.modelData.action()
                        }
                    }
                }
            }
        }
    }
}
