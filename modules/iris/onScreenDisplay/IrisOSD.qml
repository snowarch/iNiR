pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.field as Field
import qs.modules.iris.components
import qs.modules.iris.bar.island

Scope {
    id: root
    property string kind: "volume"
    property string keyboardText: ""
    property string keyboardIcon: ""
    property bool keyboardActive: false
    property string mediaAction: ""
    property string warningText: ""
    property bool open: false
    property bool presentationVisible: false
    readonly property var screen: outputHold.output
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.presentationVisible
    }
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(root.screen)
    readonly property bool fullscreen: CompositorService.isNiri
        && GameMode.hasFullscreenOnOutput(root.screen?.name ?? "") && !NiriService.inOverview
    readonly property var prefs: Config.options?.iris?.osd
    readonly property bool atTop: root.prefs?.position === "top"
    readonly property real edgeMargin: Math.max(0, Math.min(240, Number(root.prefs?.offset ?? 18))) * IrisStyle.density
        + (root.fullscreen ? 0 : IrisFrame.safeClear(root.atTop ? "top" : "bottom"))
    readonly property int holdMs: Math.max(800, Math.min(5000, Number(root.prefs?.duration ?? 1500)))
    readonly property string gameRule: root.fullscreen || GameMode.active ? String(root.prefs?.fullscreen ?? "show") : "show"
    readonly property string levelsMode: String(root.prefs?.levels ?? "yours")
    readonly property string mediaMode: String(root.prefs?.media ?? "yours")
    readonly property string levelStyle: String(root.prefs?.style ?? "capsule")
    readonly property bool levelFigure: root.prefs?.figure ?? true
    readonly property color light: root.kind === "volume" ? IrisStyle.identity.indigo
        : root.kind === "mic" ? IrisStyle.identity.orange
        : root.kind === "brightness" ? IrisStyle.secondaryAccent
        : root.kind === "warning" ? IrisStyle.danger : "transparent"

    function allows(nextKind: string): bool {
        if (root.gameRule === "hide") return false
        if (root.gameRule === "quiet") return nextKind !== "media" && nextKind !== "keyboard" && nextKind !== "connection"
        return nextKind !== "keyboard" || (root.prefs?.keyboard ?? true)
    }
    function showLevel(nextKind: string): void {
        if (root.levelsMode === "off") return
        const touched = nextKind === "brightness" ? Brightness.lastUserChange : Audio.lastUserChange
        if (root.levelsMode === "yours" && Date.now() - touched > 1200) return
        root.show(nextKind, root.holdMs)
    }

    readonly property bool level: root.kind === "volume" || root.kind === "brightness" || root.kind === "mic"
    readonly property var rows: ({ volume: levelRow, brightness: levelRow, mic: levelRow,
        keyboard: keyboardRow, media: mediaRow, warning: warningRow, connection: connectionRow })

    function show(nextKind: string, holdMs: int): void {
        if (!root.allows(nextKind)) return
        root.kind = nextKind
        root.open = true
        root.presentationVisible = true
        hideTimer.interval = holdMs
        hideTimer.restart()
    }

    function hide(): void {
        root.open = false
        GlobalStates.osdVolumeOpen = false
        GlobalStates.osdBrightnessOpen = false
        GlobalStates.osdMicOpen = false
        GlobalStates.osdMediaOpen = false
        GlobalStates.osdKeyboardLayoutOpen = false
    }

    readonly property real value: root.kind === "brightness"
        ? (root.brightnessMonitor?.brightness ?? 0)
        : root.kind === "mic"
            ? Math.max(0, Math.min(1, Audio.micVolume ?? 0))
            : Math.max(0, Math.min(1, Audio.value ?? 0))
    readonly property bool muted: root.kind === "mic" ? Audio.micMuted
        : root.kind === "volume" ? (Audio.sink?.audio?.muted ?? false) : false
    readonly property string icon: root.kind === "brightness" ? "light_mode"
        : root.kind === "mic" ? (Audio.micMuted ? "mic_off" : "mic")
        : root.muted ? "volume_off"
        : root.value < 0.34 ? "volume_mute"
        : root.value < 0.67 ? "volume_down" : "volume_up"

    readonly property var player: MprisController.activePlayer
    readonly property bool ytMusic: root.player !== null && root.player !== undefined
        && MprisController._isYtMusicMpv(root.player)
    readonly property string mediaTitle: StringUtils.cleanMusicTitle(
        root.ytMusic ? YtMusic.currentTitle : String(MprisController.titleOf(root.player) ?? ""))
    readonly property string mediaArtist: root.ytMusic ? YtMusic.currentArtist
        : String(MprisController.artistOf(root.player) ?? "")
    readonly property string mediaIcon: root.mediaAction === "next" ? "skip_next"
        : root.mediaAction === "previous" ? "skip_previous"
        : root.mediaAction === "pause" ? "pause" : "play_arrow"

    component OsdRow: RowLayout {
        id: osdRow
        property string mode: ""
        readonly property bool current: root.rows[root.kind] === osdRow
        anchors.fill: parent
        anchors.leftMargin: 13 * IrisStyle.density
        anchors.rightMargin: 16 * IrisStyle.density
        spacing: 11 * IrisStyle.density
        opacity: osdRow.current ? 1 : 0
        scale: osdRow.current ? 1 : 0.96
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
    }

    Timer { id: hideTimer; interval: 1500; onTriggered: root.hide() }
    Timer { id: warm; interval: 4000; running: true; property bool ready: false; onTriggered: warm.ready = true }

    // A request raised while the Island owned this output is still set when the
    // fallback takes over, and would never fire a change again.
    Component.onCompleted: {
        if (GlobalStates.osdVolumeOpen) root.show("volume", root.holdMs)
        else if (GlobalStates.osdBrightnessOpen) root.show("brightness", root.holdMs)
        else if (GlobalStates.osdMicOpen) root.show("mic", root.holdMs)
        else if (GlobalStates.osdMediaOpen && root.mediaMode !== "off") root.show("media", root.holdMs + 1100)
        else if (GlobalStates.osdKeyboardLayoutOpen) {
            root.keyboardIcon = "language"
            root.keyboardActive = true
            root.keyboardText = KeyboardIndicators.currentLayoutCodeInline || KeyboardIndicators.currentLayoutName
            root.show("keyboard", root.holdMs + 100)
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged(): void { root.showLevel("brightness") }
    }
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged(): void { root.showLevel("volume") }
        function onMutedChanged(): void { root.showLevel("volume") }
    }
    Connections {
        target: Audio
        function onMicVolumeChanged(): void { root.showLevel("mic") }
        function onMicMutedChanged(): void { root.showLevel("mic") }
        function onSinkProtectionTriggered(reason: string): void {
            root.warningText = reason
            root.show("warning", root.holdMs + 1100)
        }
    }
    property var connection: null
    readonly property color connectionTint: root.connection?.tone === "warn" ? IrisStyle.identity.orange
        : root.connection?.tone === "off" ? IrisStyle.subtext
        : ({ network: IrisStyle.identity.blue, internet: IrisStyle.identity.teal, bluetooth: IrisStyle.identity.blue, usb: IrisStyle.identity.sky,
             power: IrisStyle.success, audio: IrisStyle.accent, displays: IrisStyle.identity.indigo,
             drives: IrisStyle.identity.orange })[root.connection?.kind ?? ""] ?? IrisStyle.accent
    Connections {
        target: DeviceEvents
        function onHappened(event: var): void {
            root.connection = event
            root.show("connection", root.holdMs + 1100)
        }
    }
    Connections {
        target: warm.ready ? KeyboardIndicators : null
        function onPopupSequenceChanged(): void {
            if (!KeyboardIndicators.ready) return
            root.keyboardIcon = KeyboardIndicators.popupMaterialIcon
            root.keyboardActive = KeyboardIndicators.popupActive
            root.keyboardText = KeyboardIndicators.popupKind === "layout"
                ? (KeyboardIndicators.currentLayoutCodeInline || KeyboardIndicators.popupText)
                : KeyboardIndicators.popupText
            root.show("keyboard", root.holdMs + 100)
        }
    }
    Connections {
        target: MprisController
        function onTrackChanged(reverse: bool): void {
            if (!warm.ready || root.mediaTitle.length === 0) return
            if (root.kind === "media" && root.open) {
                hideTimer.restart()
                return
            }
            if (root.mediaMode !== "every") return
            root.mediaAction = ""
            root.show("media", root.holdMs + 1100)
        }
    }
    Connections {
        target: GlobalStates
        function onOsdVolumeOpenChanged(): void { if (GlobalStates.osdVolumeOpen) root.show("volume", root.holdMs) }
        function onOsdBrightnessOpenChanged(): void { if (GlobalStates.osdBrightnessOpen) root.show("brightness", root.holdMs) }
        function onOsdMicOpenChanged(): void { if (GlobalStates.osdMicOpen) root.show("mic", root.holdMs) }
        function onOsdKeyboardLayoutOpenChanged(): void {
            if (!GlobalStates.osdKeyboardLayoutOpen) return
            root.keyboardIcon = "language"
            root.keyboardActive = true
            root.keyboardText = KeyboardIndicators.currentLayoutCodeInline || KeyboardIndicators.currentLayoutName
            root.show("keyboard", root.holdMs + 100)
        }
        function onOsdMediaActionTriggered(action: string): void {
            if (root.mediaMode === "off") return
            root.mediaAction = action
            root.show("media", root.holdMs + 1100)
        }
    }

    PanelWindow {
        id: osdWindow
        visible: root.presentationVisible
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:iris-osd"
        Field.IrisBlurRegion {
            id: placeBlur
            window: osdWindow
            shapes: body.blurShapes
            windowWidth: osdWindow.width
            windowHeight: osdWindow.height
        }
        anchors { bottom: !root.atTop; top: root.atTop; left: true; right: true }
        margins {
            left: root.fullscreen ? 0 : IrisFrame.safeClear("left")
            right: root.fullscreen ? 0 : IrisFrame.safeClear("right")
        }
        implicitHeight: Math.round(root.edgeMargin + 110 * IrisStyle.density)
        mask: Region {}

        readonly property real d: IrisStyle.density
        readonly property Item activeRow: root.rows[root.kind] ?? levelRow
        readonly property real restWidth: Math.max(260, Math.min(520,
            Number(Config.options?.iris?.osd?.width ?? 320))) * osdWindow.d
        readonly property real pad: 29 * osdWindow.d
        readonly property real targetHeight: Math.round((root.kind === "media" || root.kind === "connection" ? 64 : root.level && root.levelStyle === "minimal" ? 48 : 54) * osdWindow.d)
        readonly property real targetWidth: Math.round(Math.min(osdWindow.width - 24,
            root.level && root.levelStyle !== "minimal" ? osdWindow.restWidth
                : Math.max(osdWindow.targetHeight * 2.2, Math.min(osdWindow.restWidth * 1.2,
                    osdWindow.activeRow.implicitWidth + osdWindow.pad))))
        readonly property real core: osdWindow.targetHeight

        IrisSpring { id: widthSpring; intent: "move"; surface: "osd"; to: osdWindow.targetWidth; animate: body.presentation > 0 }
        IrisSpring { id: heightSpring; intent: "move"; surface: "osd"; to: osdWindow.targetHeight; animate: body.presentation > 0 }

        RectangularShadow {
            readonly property var rect: body.bodyRect
            x: rect.x
            y: rect.y + (root.atTop ? 4 : 6) * osdWindow.d * body.progress
            width: rect.width
            height: rect.height
            radius: rect.radius
            blur: 26 * osdWindow.d
            spread: -5 * osdWindow.d
            color: IrisStyle.shadow
            opacity: IrisStyle.shadowAt(body.progress)
        }

        IrisMorphSurface {
            id: body
            compositorBlurred: true
            open: root.open
            motionSurface: "osd"
            // Over a fullscreen window the wallpaper is not behind it, but the compositor's blur is.
            glass: !root.fullscreen || IrisStyle.glassCompositor
            ownField: true
            windowOffset: Qt.point(osdWindow.margins.left, root.atTop ? 0 : (root.screen?.height ?? osdWindow.height) - osdWindow.height)
            color: IrisStyle.surface
            light: IrisStyle.surfaceLight("osd", root.light)
            lightFrom: root.atTop ? "top" : "bottom"
            radius: IrisStyle.surfaceRadius("osd", IrisStyle.pieceRadius(heightSpring.value))
            origin: ({ x: (osdWindow.width - osdWindow.core) / 2, y: root.atTop ? -osdWindow.core : osdWindow.height,
                width: osdWindow.core, height: osdWindow.core, radius: osdWindow.core / 2 })
            width: Math.round(widthSpring.value)
            height: Math.round(heightSpring.value)
            x: Math.round((osdWindow.width - width) / 2)
            y: Math.round(root.atTop ? root.edgeMargin : osdWindow.height - height - root.edgeMargin)
            onClosed: root.presentationVisible = false

            OsdRow {
                id: levelRow
                LevelFace {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    glyph: root.icon
                    value: root.value
                    muted: root.muted
                    style: root.levelStyle
                    showValue: root.levelFigure
                    glyphSize: 20 * osdWindow.d
                    figureSize: 15 * IrisStyle.typeScale
                    barFill: IrisStyle.text
                }
            }

            OsdRow {
                id: keyboardRow
                Glyph {
                    text: root.keyboardIcon
                    iconSize: 20 * osdWindow.d
                    color: root.keyboardActive ? IrisStyle.accent : IrisStyle.subtext
                    Layout.preferredWidth: 22 * osdWindow.d
                }
                IrisText {
                    Layout.fillWidth: true
                    text: root.keyboardText
                    elide: Text.ElideRight
                    font.pixelSize: IrisStyle.typeBody
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    color: root.keyboardActive ? IrisStyle.text : IrisStyle.subtext
                }
            }

            OsdRow {
                id: mediaRow
                IrisArtwork {
                    Layout.preferredWidth: 40 * osdWindow.d
                    Layout.preferredHeight: 40 * osdWindow.d
                    circular: false
                    radius: IrisStyle.iconRadius(40 * osdWindow.d)
                    source: MediaArtwork.displaySource
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        Layout.fillWidth: true
                        text: root.mediaTitle.length > 0 ? root.mediaTitle : Translation.tr("Now playing")
                        elide: Text.ElideRight
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: root.mediaArtist.length > 0
                        text: root.mediaArtist
                        elide: Text.ElideRight
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeMeta
                    }
                }
                Glyph {
                    visible: root.mediaAction.length > 0
                    text: root.mediaIcon
                    iconSize: 20 * osdWindow.d
                    color: IrisStyle.accent
                }
            }

            OsdRow {
                id: connectionRow
                Glyph {
                    text: root.connection?.icon ?? ""
                    iconSize: 20 * osdWindow.d
                    color: root.connectionTint
                    Layout.preferredWidth: 22 * osdWindow.d
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        Layout.fillWidth: true
                        text: root.connection?.title ?? ""
                        elide: Text.ElideRight
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: root.connection?.detail ?? ""
                        elide: Text.ElideRight
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeMeta
                    }
                }
                IrisText {
                    visible: (root.connection?.value ?? -1) >= 0
                    text: (root.connection?.value ?? 0) + "%"
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeMeta
                    font.features: ({ "tnum": 1 })
                }
            }

            OsdRow {
                id: warningRow
                Glyph {
                    text: "volume_off"
                    iconSize: 20 * osdWindow.d
                    color: IrisStyle.danger
                    Layout.preferredWidth: 22 * osdWindow.d
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        Layout.fillWidth: true
                        text: Translation.tr("Volume held back")
                        elide: Text.ElideRight
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: root.warningText.length > 0
                        text: root.warningText
                        elide: Text.ElideRight
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeMeta
                    }
                }
            }
        }
    }
}
