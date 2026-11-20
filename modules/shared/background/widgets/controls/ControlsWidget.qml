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

    // Stable list of toggle ids: it changes only with the chosen set. Each delegate reads its live state
    // from the services through ControlsToggle, so a state change never rebuilds a delegate and the Behaviors play.
    readonly property var toggleIds: root.toggleSet === "evening" ? ["night", "dnd", "dark", "awake"]
        : root.toggleSet === "sound" ? ["mute", "mic", "dnd", "gamemode"]
        : ["wifi", "bt", "dnd", "night"]

    // One toggle: its state comes from the services by id; shape and role come from its slot in the set.
    component ControlsToggle: QtObject {
        id: toggle
        required property string tid
        required property int slot
        readonly property var shapes: [MaterialShape.Shape.Cookie9Sided, MaterialShape.Shape.Clover4Leaf, MaterialShape.Shape.Sunny, MaterialShape.Shape.Flower]
        readonly property var roles: [root.widgetPrimaryRole, root.widgetSecondaryRole, root.widgetTertiaryRole, root.widgetPrimaryRole]
        readonly property var shape: toggle.shapes[toggle.slot % 4]
        readonly property string role: toggle.roles[toggle.slot % 4]

        readonly property bool sinkMuted: Audio.sink?.audio?.muted ?? false
        readonly property bool micActive: Audio.source !== null && !Audio.micMuted
        readonly property string btSummary: toggle.tid === "bt" ? (BluetoothStatus.activeDeviceSummary() || "") : ""

        readonly property string label: {
            switch (toggle.tid) {
            case "night": return Translation.tr("Night light")
            case "dnd": return Translation.tr("Focus")
            case "dark": return Translation.tr("Dark mode")
            case "awake": return Translation.tr("Keep awake")
            case "mute": return Translation.tr("Output")
            case "mic": return Translation.tr("Microphone")
            case "gamemode": return Translation.tr("Game mode")
            case "wifi": return Network.ethernet ? Translation.tr("Ethernet") : (Network.networkName || Translation.tr("Wi-Fi"))
            case "bt": return toggle.btSummary.length > 0 ? toggle.btSummary : Translation.tr("Bluetooth")
            }
            return ""
        }
        readonly property string sub: {
            switch (toggle.tid) {
            case "night": return Hyprsunset.active ? Translation.tr("On") : Translation.tr("Off")
            case "dnd": return Notifications.manualDndActive ? Translation.tr("Quiet") : Translation.tr("Off")
            case "dark": return Appearance.m3colors.darkmode ? Translation.tr("On") : Translation.tr("Light")
            case "awake": return Idle.inhibit ? Translation.tr("Active") : Translation.tr("Off")
            case "mute": return toggle.sinkMuted ? Translation.tr("Muted") : Math.round(Math.min(1, Audio.value ?? 0) * 100) + "%"
            case "mic": return toggle.micActive ? Translation.tr("Live") : Translation.tr("Muted")
            case "gamemode": return GameMode.active ? Translation.tr("Active") : Translation.tr("Off")
            case "wifi": return Network.ethernet ? Translation.tr("Wired") : (Network.wifiEnabled ? (Network.networkName ? Translation.tr("Connected") : Translation.tr("On")) : Translation.tr("Off"))
            case "bt": return toggle.btSummary.length > 0 ? Translation.tr("Connected") : (BluetoothStatus.enabled ? Translation.tr("On") : Translation.tr("Off"))
            }
            return ""
        }
        readonly property string icon: {
            switch (toggle.tid) {
            case "night": return "nightlight"
            case "dnd": return Notifications.manualDndActive ? "do_not_disturb_on" : "notifications"
            case "dark": return Appearance.m3colors.darkmode ? "dark_mode" : "light_mode"
            case "awake": return "coffee"
            case "mute": return toggle.sinkMuted ? "volume_off" : "volume_up"
            case "mic": return toggle.micActive ? "mic" : "mic_off"
            case "gamemode": return "sports_esports"
            case "wifi": return Network.ethernet ? "lan" : (Network.wifiEnabled ? "wifi" : "wifi_off")
            case "bt": return BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
            }
            return ""
        }
        readonly property bool active: {
            switch (toggle.tid) {
            case "night": return Hyprsunset.active
            case "dnd": return Notifications.manualDndActive
            case "dark": return Appearance.m3colors.darkmode
            case "awake": return Idle.inhibit
            case "mute": return !toggle.sinkMuted
            case "mic": return toggle.micActive
            case "gamemode": return GameMode.active
            case "wifi": return Network.ethernet || Network.wifiEnabled
            case "bt": return BluetoothStatus.enabled
            }
            return false
        }
        readonly property bool available: {
            switch (toggle.tid) {
            case "mute": return Audio.sink !== null
            case "mic": return Audio.source !== null
            case "bt": return BluetoothStatus.available
            }
            return true
        }
        function trigger() {
            switch (toggle.tid) {
            case "night": Hyprsunset.toggle(); break
            case "dnd": Notifications.toggleSilent(); break
            case "dark": Appearance.toggleDarkMode(); break
            case "awake": Idle.toggleInhibit(); break
            case "mute": Audio.toggleMute(); break
            case "mic": Audio.toggleMicMute(); break
            case "gamemode": GameMode.toggle(); break
            case "wifi": Network.toggleWifi(); break
            case "bt": if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled; break
            }
        }
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
                    model: root.controlsStyle === "shapes" ? root.toggleIds : []

                    Item {
                        id: shapeToggle
                        required property string modelData
                        required property int index
                        ControlsToggle { id: shapeInfo; tid: shapeToggle.modelData; slot: shapeToggle.index }
                        width: shapesGrid.cellSize
                        height: shapesGrid.cellSize
                        opacity: shapeInfo.available ? 1 : 0.45

                        readonly property var mark: root.widgetMark(shapeInfo.role)
                        readonly property color activeFill: root.widgetHasSurface
                            ? root.widgetSemanticColor(shapeInfo.role)
                            : shapeToggle.mark.fill
                        readonly property color activeInk: root.widgetHasSurface
                            ? root.widgetSemanticOnColor(shapeInfo.role)
                            : shapeToggle.mark.ink
                        readonly property color offFill: root.widgetHasSurface
                            ? ColorUtils.applyAlpha(root.widgetInk, shapeTap.containsMouse ? 0.16 : 0.10)
                            : ColorUtils.applyAlpha(root.widgetPlateColor, shapeTap.containsMouse ? 0.88 : 0.76)

                        MaterialShape {
                            anchors.fill: parent
                            shape: shapeInfo.active ? shapeInfo.shape : MaterialShape.Shape.Circle
                            color: shapeInfo.active ? shapeToggle.activeFill : shapeToggle.offFill
                            rotation: shapeInfo.active ? 18 : 0
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
                                text: shapeInfo.icon
                                fill: shapeInfo.active ? 1 : 0
                                iconSize: Math.round(shapeToggle.width * 0.36)
                                color: shapeInfo.active ? shapeToggle.activeInk : root.widgetInk
                            }
                        }

                        MouseArea {
                            id: shapeTap
                            anchors.fill: parent
                            enabled: shapeInfo.available
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shapeInfo.trigger()
                        }

                        StyledToolTip {
                            extraVisibleCondition: shapeTap.containsMouse
                            text: `${shapeInfo.label} · ${shapeInfo.sub}`
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
                    model: root.controlsStyle === "row" ? root.toggleIds : []

                    Rectangle {
                        id: rowBtn
                        required property string modelData
                        required property int index
                        ControlsToggle { id: rowInfo; tid: rowBtn.modelData; slot: rowBtn.index }
                        width: rowStrip.btnSize
                        height: rowStrip.btnSize
                        radius: rowInfo.active ? Math.round(14 * root.scaleFactor) : width / 2
                        opacity: rowInfo.available ? 1 : 0.45
                        color: rowInfo.active
                            ? root.widgetSemanticColor(rowInfo.role)
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
                            text: rowInfo.icon
                            fill: rowInfo.active ? 1 : 0
                            iconSize: Math.round(rowBtn.width * 0.44)
                            color: rowInfo.active
                                ? root.widgetSemanticOnColor(rowInfo.role)
                                : root.widgetInk
                        }

                        MouseArea {
                            id: rowTap
                            anchors.fill: parent
                            enabled: rowInfo.available
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rowInfo.trigger()
                        }

                        StyledToolTip {
                            extraVisibleCondition: rowTap.containsMouse
                            text: `${rowInfo.label} · ${rowInfo.sub}`
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
                    model: root.controlsStyle === "tiles" ? root.toggleIds : []

                    Rectangle {
                        id: tileCard
                        required property string modelData
                        required property int index
                        ControlsToggle { id: tileInfo; tid: tileCard.modelData; slot: tileCard.index }
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 1
                        opacity: tileInfo.available ? 1 : 0.45
                        radius: tileInfo.active
                            ? Math.min(root.widgetCardRadius, Math.round(16 * root.scaleFactor))
                            : height / 2
                        color: tileInfo.active
                            ? root.widgetSemanticContainer(tileInfo.role)
                            : ColorUtils.applyAlpha(root.widgetInk, tileTap.containsMouse ? 0.14 : 0.08)
                        scale: tileTap.pressed ? 0.96 : 1.0

                        readonly property color fg: tileInfo.active
                            ? root.widgetSemanticOnContainer(tileInfo.role)
                            : root.widgetInk
                        readonly property color subFg: tileInfo.active
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
                                text: tileInfo.icon
                                fill: tileInfo.active ? 1 : 0
                                iconSize: Math.round((root.isSmall ? 18 : 20) * root.scaleFactor)
                                color: tileCard.fg
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: tileInfo.label
                                    color: tileCard.fg
                                    font.family: root.widgetBodyFamily
                                    font.pixelSize: Math.round((root.isSmall ? 11 : 12.5) * root.scaleFactor)
                                    font.weight: Font.DemiBold
                                }

                                StyledText {
                                    visible: !root.isSmall && tileCard.height >= Math.round(44 * root.scaleFactor)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: tileInfo.sub
                                    color: tileCard.subFg
                                    font.family: root.widgetBodyFamily
                                    font.pixelSize: Math.round(10.5 * root.scaleFactor)
                                }
                            }
                        }

                        MouseArea {
                            id: tileTap
                            anchors.fill: parent
                            enabled: tileInfo.available
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tileInfo.trigger()
                        }
                    }
                }
            }
        }
    }
}
