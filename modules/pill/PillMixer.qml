import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import qs.services
import qs.modules.common

/**
 * Mixer surface: header with a night-light chip and a row of vertical ink-faders
 * wired to real hardware — external monitor and backlight brightness through
 * iNiR's Brightness service, volume and mic through Pipewire. Fills the lower
 * body of the pill.
 *
 * Upstream also carried a digital-vibrance fader; that needs nvibrant (nvidia
 * only), which iNiR does not depend on, so the fader is gone rather than dead.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 14
    mRight: 14
    mBottom: 12

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    /**
     * Output devices the user can make default: real sinks only, never the
     * per-app playback streams. Sorted by label so the list order stays stable
     * as nodes appear and vanish.
     */
    readonly property var outputSinks: {
        void Pipewire.nodes.values;
        var out = [];
        var all = Pipewire.nodes.values;
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isSink && !n.isStream && n.audio)
                out.push(n);
        }
        out.sort((a, b) => root.deviceLabel(a).localeCompare(root.deviceLabel(b)));
        return out;
    }

    /**
     * Input devices the user can make default: real sources only. The sink
     * monitors that Pipewire exposes alongside real mics also match isSink=false,
     * so they are dropped by name to keep the list to actual capture devices.
     */
    readonly property var inputSources: {
        void Pipewire.nodes.values;
        var out = [];
        var all = Pipewire.nodes.values;
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && !n.isSink && !n.isStream && n.audio && !/monitor/i.test(n.name || ""))
                out.push(n);
        }
        out.sort((a, b) => root.deviceLabel(a).localeCompare(root.deviceLabel(b)));
        return out;
    }

    function deviceLabel(node) {
        if (!node)
            return "";
        return node.description || node.nickname || node.name || "";
    }

    /** Which device dropdown is open: "out", "in", or "" for none. */
    property string openPicker: ""

    property int focusIndex: -1
    readonly property int faderCount: faders.length
    readonly property var faders: {
        void brRep.count;
        void blLoader.item;
        var out = [];
        for (var i = 0; i < brRep.count; i++) {
            var f = brRep.itemAt(i);
            if (f)
                out.push(f);
        }
        if (blLoader.item)
            out.push(blLoader.item);
        out.push(volFader, micFader);
        return out;
    }
    readonly property bool surfaceHovered: hoverTracker.hovered

    /**
     * Tick centre of the focused fader, mapped into this mixer's root so the
     * bead glides as keyboard/hover focus moves across the row. Layout deps are
     * voided before mapToItem so the binding re-evaluates on resize (else stale).
     */
    readonly property point focusTickPoint: {
        void root.width;
        void root.height;
        void root.focusIndex;
        const i = Math.max(0, Math.min(faders.length - 1, root.focusIndex));
        const f = faders[i];
        if (!f)
            return Qt.point(0, 0);
        return f.mapToItem(root, f.tickCenter.x, f.tickCenter.y);
    }

    ameForm: "tick"
    amePoint: focusTickPoint

    /**
     * Pointer-driven fader targeting. MouseArea hover is flaky on this
     * layer-shell surface, so a non-blocking HoverHandler is the only hover
     * source. Its pointer x maps to a fader column and drives keyboard focus.
     */
    readonly property int hoverIndex: surfaceHovered && width > 0 && faders.length > 0
        && hoverTracker.point.position.y >= faderRow.y
        ? Math.max(0, Math.min(faders.length - 1, Math.floor(hoverTracker.point.position.x / (width / faders.length))))
        : -1
    onHoverIndexChanged: if (hoverIndex >= 0 && !keyLatch.running) focusIndex = hoverIndex

    HoverHandler {
        id: hoverTracker
    }

    /**
     * Brief keyboard-nav precedence: an arrow keypress latches focus for
     * PillMotion.standard so a stray pointer move doesn't yank the target away
     * mid-navigation. Hover resumes driving focus once it lapses.
     */
    Timer {
        id: keyLatch
        interval: PillMotion.standard
    }

    onActiveChanged: {
        focusIndex = active ? 0 : -1;
        if (!active)
            openPicker = "";
    }

    /**
     * Nudge the focused fader by `deltaPct` percent. Returns true when a fader
     * handled the step.
     */
    function stepFocused(deltaPct) {
        if (focusIndex < 0)
            return false;
        faders[focusIndex].step(deltaPct);
        keyLatch.restart();
        return true;
    }

    /**
     * Move keyboard focus across the fader row, wrapping at the ends. `dir` is +1
     * (right) or -1 (left); a fresh focus lands on the first or last fader.
     */
    function moveFocus(dir) {
        focusIndex = focusIndex < 0 ? (dir > 0 ? 0 : faders.length - 1)
                                    : (focusIndex + dir + faders.length) % faders.length;
        keyLatch.restart();
    }

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.outputSinks).concat(root.inputSources).filter(Boolean)
    }

    component IconChip: Rectangle {
        id: chip
        property string glyph: ""
        property bool on: false
        property string tipTitle: ""
        property string tipDesc: ""
        signal toggled()

        width: 26 * root.s
        height: 26 * root.s
        radius: 8 * root.s
        color: chip.on ? PillTheme.frameBg : "transparent"
        border.width: 1
        border.color: chip.on ? PillTheme.frameBorder : PillTheme.border

        GlyphIcon {
            anchors.centerIn: parent
            width: 15 * root.s
            height: 15 * root.s
            name: chip.glyph
            color: chip.on ? PillTheme.vermLit : PillTheme.iconDim
            stroke: 1.7
        }
        HoverHandler {
            id: chipHover
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.toggled()
        }

        Tooltip {
            s: root.s
            placement: "below"
            title: chip.tipTitle
            desc: chip.tipDesc
            show: chipHover.hovered
        }
    }

    /**
     * Header device picker: an icon-only button that toggles its dropdown. It
     * reads as an open field (onGlow tint and border) while its list is showing,
     * the same affordance the display surface uses, so no chevron is needed.
     */
    component DevicePickerChip: Rectangle {
        id: dchip
        property string glyph: ""
        property bool open: false
        property string tip: ""
        signal toggled()

        width: 26 * root.s
        height: 26 * root.s
        radius: 8 * root.s
        color: dchip.open ? Qt.alpha(PillTheme.onGlow, 0.14)
            : (dchipHover.hovered ? PillTheme.frameBg : "transparent")
        border.width: 1
        border.color: dchip.open ? Qt.alpha(PillTheme.onGlow, 0.5) : PillTheme.border
        Behavior on color { ColorAnimation { duration: PillMotion.fast } }

        GlyphIcon {
            anchors.centerIn: parent
            width: 15 * root.s
            height: 15 * root.s
            name: dchip.glyph
            color: dchip.open ? PillTheme.vermLit : PillTheme.iconDim
            stroke: 1.7
        }
        HoverHandler {
            id: dchipHover
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: dchip.toggled()
        }

        Tooltip {
            s: root.s
            placement: "below"
            title: dchip.tip
            show: dchipHover.hovered && !dchip.open
        }
    }

    Item {
        id: header
        z: 5
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: PillTheme.showGlyphs
                text: PillTheme.glyph("mixer")
                color: PillTheme.cream
                font.family: PillTheme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("MIXER")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s
            DevicePickerChip {
                glyph: "speaker"
                open: root.openPicker === "out"
                tip: "Output device"
                onToggled: root.openPicker = root.openPicker === "out" ? "" : "out"
            }
            DevicePickerChip {
                glyph: "mic"
                open: root.openPicker === "in"
                tip: "Input device"
                onToggled: root.openPicker = root.openPicker === "in" ? "" : "in"
            }
            IconChip {
                glyph: "dnd"
                on: Notifications.manualDndActive
                tipTitle: Translation.tr("Do not disturb")
                tipDesc: Notifications.manualDndActive
                    ? Translation.tr("Silence notifications")
                    : Notifications.quietHoursActive
                        ? Translation.tr("Quiet hours")
                        : Translation.tr("Silence notifications")
                onToggled: Notifications.toggleSilent()
            }
            IconChip {
                glyph: "awake"
                on: Idle.inhibit
                tipTitle: Translation.tr("Keep awake")
                tipDesc: Translation.tr("Block sleep & screen-off")
                onToggled: Idle.toggleInhibit()
            }
            IconChip {
                glyph: "sun"
                on: Hyprsunset.active
                tipTitle: Translation.tr("Night light")
                tipDesc: Translation.tr("Warm the screen")
                onToggled: Hyprsunset.toggle(!Hyprsunset.active)
            }
            IconChip {
                glyph: "gamepad"
                on: GameMode.active
                tipTitle: Translation.tr("Game mode")
                tipDesc: Notifications.gameModeSuppressionActive
                    ? Translation.tr("Hide notification popups while Game Mode is active")
                    : Translation.tr("Strip effects, quiet the desktop")
                onToggled: GameMode.toggle()
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: PillTheme.hair
    }

    /**
     * Device dropdown overlay. Both the output and input pickers reuse this: the
     * `kind` ("out"/"in") keys it to root.openPicker, `model` is the node list,
     * `current` is the active default, and `onPick` writes the matching
     * preferredDefault. It floats above the faders right-aligned under the header
     * so the mixer height stays fixed while a list is open.
     */
    component DeviceMenu: Item {
        id: menu
        property string kind: ""
        property var model: []
        property var current
        signal pick(var node)

        readonly property bool open: root.openPicker === kind
        z: 7
        visible: open
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.right: parent.right
        width: 300 * root.s
        height: panel.height

        /**
         * Shadow caster kept apart from the option text. A layer over the labels
         * would rasterise the glyphs and soften them, so the halo lives on this
         * textless backing rect and the panel above stays unlayered and crisp.
         */
        Rectangle {
            anchors.fill: panel
            visible: menu.open
            radius: panel.radius
            color: PillTheme.cardBot
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: PillTheme.shadow
                shadowBlur: 0.6
                shadowVerticalOffset: 4 * root.s
            }
        }

        Rectangle {
            id: panel
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.min(menu.model.length * 24 * root.s + 4 * root.s, 150 * root.s)
            clip: true
            radius: 9 * root.s
            gradient: Gradient {
                GradientStop { position: 0.0; color: PillTheme.cardTop }
                GradientStop { position: 1.0; color: PillTheme.cardBot }
            }
            border.width: 1
            border.color: PillTheme.frameBorder

            ListView {
                anchors.fill: parent
                anchors.margins: 2 * root.s
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: menu.model

                delegate: Rectangle {
                    id: devRow
                    required property var modelData
                    readonly property bool current: menu.current === modelData

                    width: ListView.view.width
                    height: 24 * root.s
                    radius: 7 * root.s
                    color: devRowHover.hovered ? PillTheme.frameBg
                        : (devRow.current ? Qt.alpha(PillTheme.onGlow, 0.16) : "transparent")

                    HoverHandler { id: devRowHover }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 9 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.deviceLabel(devRow.modelData)
                        elide: Text.ElideRight
                        color: devRow.current ? PillTheme.cream : PillTheme.subtle
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: devRow.current ? Font.Bold : Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            menu.pick(devRow.modelData);
                            root.openPicker = "";
                        }
                    }
                }
            }
        }
    }

    DeviceMenu {
        kind: "out"
        model: root.outputSinks
        current: root.sink
        onPick: (node) => Pipewire.preferredDefaultAudioSink = node
    }

    DeviceMenu {
        kind: "in"
        model: root.inputSources
        current: root.source
        onPick: (node) => Pipewire.preferredDefaultAudioSource = node
    }

    Row {
        id: faderRow
        anchors.top: divider.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 142 * root.s
        spacing: 0

        readonly property real colW: width / Math.max(1, root.faderCount)

        /**
         * Brightness faders bind straight to the live BrightnessMonitor
         * objects, so a change from the OSD keys or another monitor's fader
         * moves them too. Writes go through the service, which already owns
         * the DDC debounce; no second ddcutil path in here. The 5% floor
         * keeps a DDC monitor from being dragged into a black screen.
         */
        Repeater {
            id: brRep
            model: PillDevices.ddcMonitors

            VFader {
                required property var modelData
                required property int index

                width: faderRow.colW
                s: root.s
                icon: "sun"
                subLabel: PillDevices.ddcMonitors.length > 1
                    ? (modelData.screen?.name || Translation.tr("Brightness"))
                    : Translation.tr("Brightness")
                subPersistent: false
                focused: root.focusIndex === index
                value: modelData.brightness
                valueLabel: Math.round(modelData.brightness * 100) + "%"
                onMoved: (v) => modelData.setBrightness(Math.max(0.05, v))
            }
        }

        Loader {
            id: blLoader
            active: PillDevices.backlightPresent
            visible: active
            width: active ? faderRow.colW : 0

            sourceComponent: VFader {
                width: faderRow.colW
                s: root.s
                icon: "sun"
                subLabel: Translation.tr("Backlight")
                subPersistent: false
                focused: root.focusIndex === brRep.count
                value: PillDevices.internalMonitor?.brightness ?? 0
                valueLabel: Math.round((PillDevices.internalMonitor?.brightness ?? 0) * 100) + "%"
                onMoved: (v) => PillDevices.internalMonitor?.setBrightness(Math.max(0.01, v))
            }
        }

        VFader {
            id: volFader
            width: faderRow.colW
            s: root.s
            muted: root.sink && root.sink.audio ? root.sink.audio.muted : false
            iconClickable: true
            icon: muted ? "speaker-off" : "speaker"
            subLabel: Translation.tr("Volume")
            subPersistent: false
            focused: root.focusIndex === root.faderCount - 2
            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            valueLabel: muted ? Translation.tr("off")
                : Math.round((root.sink && root.sink.audio ? root.sink.audio.volume : 0) * 100) + "%"
            onMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
            onIconClicked: { if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted; }
        }
        VFader {
            id: micFader
            width: faderRow.colW
            s: root.s
            muted: root.source && root.source.audio ? root.source.audio.muted : false
            iconClickable: true
            icon: muted ? "mic-off" : "mic"
            subLabel: Translation.tr("Microphone")
            subPersistent: false
            focused: root.focusIndex === root.faderCount - 1
            value: root.source && root.source.audio ? root.source.audio.volume : 0
            valueLabel: muted ? Translation.tr("off")
                : Math.round((root.source && root.source.audio ? root.source.audio.volume : 0) * 100) + "%"
            onMoved: (v) => { if (root.source && root.source.audio) root.source.audio.volume = v; }
            onIconClicked: { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted; }
        }
    }

    MouseArea {
        id: wheelArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: (event) => {
            acc += event.angleDelta.y / 120;
            const notches = Math.trunc(acc);
            if (notches !== 0 && root.stepFocused(notches * 5))
                acc -= notches;
            event.accepted = true;
        }
    }
}
