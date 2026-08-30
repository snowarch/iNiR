import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import qs.modules.common

/**
 * Mixer surface: application streams are the primary view, with a large master
 * output thread and one direct volume thread per PipeWire stream. System keeps
 * the hardware brightness, output and microphone faders in a separate view.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 14
    mRight: 14
    mBottom: 12

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var appNodes: MprisController.mixerAppNodes
    readonly property int appFaderLimit: Math.max(3, Math.min(8, Config.options?.bar?.pill?.mixerAppRows ?? 5))
    readonly property int visibleAppFaders: Math.max(1, Math.min(appFaderLimit, appNodes.length || 1))
    property string view: "apps"
    readonly property real desiredWidth: view === "apps"
        ? Math.min(760, Math.max(520, 132 + visibleAppFaders * 100)) * s
        : Math.max(520, 104 * Math.max(4, faderCount)) * s
    readonly property real desiredHeight: view === "apps" ? 316 * s : 300 * s

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

    function stepVolume(audio, delta) {
        if (!audio)
            return;
        audio.volume = Math.max(0, Math.min(1, audio.volume + delta));
    }

    /** Which device picker is open: "out", "in", or "" for none. */
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

    readonly property point appVolumePoint: {
        void root.width;
        void root.height;
        void masterTrack.height;
        const volume = Math.max(0, Math.min(1, root.sink?.audio?.volume ?? 0));
        return masterTrack.mapToItem(root, masterTrack.width / 2, (1 - volume) * masterTrack.height);
    }

    ameForm: view === "apps" ? "seam" : "tick"
    amePoint: view === "apps" ? appVolumePoint : focusTickPoint

    /**
     * Pointer-driven fader targeting. MouseArea hover is flaky on this
     * layer-shell surface, so a non-blocking HoverHandler is the only hover
     * source. Its pointer x maps to a fader column and drives keyboard focus.
     */
    readonly property int hoverIndex: view === "system" && surfaceHovered && width > 0 && faders.length > 0
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
        if (active)
            view = "apps";
        else
            openPicker = "";
    }

    /**
     * Nudge the focused fader by `deltaPct` percent. Returns true when a fader
     * handled the step.
     */
    function stepFocused(deltaPct) {
        if (view !== "system" || focusIndex < 0)
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
        if (view !== "system")
            return;
        focusIndex = focusIndex < 0 ? (dir > 0 ? 0 : faders.length - 1)
                                    : (focusIndex + dir + faders.length) % faders.length;
        keyLatch.restart();
    }

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.outputSinks).concat(root.inputSources).filter(Boolean)
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

        width: 34 * root.s
        height: 34 * root.s
        radius: 11 * root.s
        color: dchip.open ? Qt.alpha(PillTheme.onGlow, 0.14)
            : (dchipHover.hovered ? PillTheme.frameBg : "transparent")
        border.width: 1
        border.color: dchip.open ? Qt.alpha(PillTheme.onGlow, 0.5) : PillTheme.border
        Behavior on color { ColorAnimation { duration: PillMotion.fast } }

        GlyphIcon {
            anchors.centerIn: parent
            width: 18 * root.s
            height: 18 * root.s
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
        height: 36 * root.s

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
                font.pixelSize: 18 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("MIXER")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        SettingsSeg {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            value: root.view
            options: [
                { label: Translation.tr("Applications"), value: "apps" },
                { label: Translation.tr("System"), value: "system" }
            ]
            onPicked: (value) => {
                root.view = value;
                root.openPicker = "";
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
        width: 360 * root.s
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
            height: Math.min(menu.model.length * 36 * root.s + 4 * root.s, 184 * root.s)
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
                    height: 36 * root.s
                    radius: 9 * root.s
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
                        font.pixelSize: 12 * root.s
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

    Item {
        id: appView
        visible: root.view === "apps"
        anchors.top: divider.bottom
        anchors.topMargin: 12 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Item {
            id: masterFader
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 104 * root.s

            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: Translation.tr("Output")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
            }

            Text {
                id: masterPct
                anchors.top: parent.top
                anchors.topMargin: 26 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.sink?.audio?.muted ? Translation.tr("off") : Math.round((root.sink?.audio?.volume ?? 0) * 100) + "%"
                color: PillTheme.cream
                font.family: PillTheme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }

            Rectangle {
                id: masterTrack
                anchors.top: masterPct.bottom
                anchors.topMargin: 12 * root.s
                anchors.bottom: masterIcon.top
                anchors.bottomMargin: 13 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                width: 8 * root.s
                radius: width / 2
                color: PillTheme.threadBg

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * Math.max(0, Math.min(1, root.sink?.audio?.volume ?? 0))
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: PillTheme.vermLit }
                        GradientStop { position: 1.0; color: PillTheme.vermBurn }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(0, Math.min(parent.height - height,
                        (1 - Math.max(0, Math.min(1, root.sink?.audio?.volume ?? 0))) * parent.height - height / 2))
                    width: 20 * root.s
                    height: 3 * root.s
                    radius: 2 * root.s
                    color: PillTheme.tickRest
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -12 * root.s
                    cursorShape: Qt.PointingHandCursor
                    function apply(mouseY) {
                        if (!root.sink?.audio)
                            return;
                        const localY = mouseY + 12 * root.s;
                        root.sink.audio.volume = 1 - Math.max(0, Math.min(1, localY / masterTrack.height));
                    }
                    onPressed: (mouse) => apply(mouse.y)
                    onPositionChanged: (mouse) => { if (pressed) apply(mouse.y); }
                    onWheel: (event) => {
                        root.stepVolume(root.sink?.audio, event.angleDelta.y > 0 ? 0.05 : -0.05);
                        event.accepted = true;
                    }
                }
            }

            GlyphIcon {
                id: masterIcon
                anchors.bottom: masterDevice.top
                anchors.bottomMargin: 5 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                width: 25 * root.s
                height: 25 * root.s
                name: root.sink?.audio?.muted ? "speaker-off" : "speaker"
                color: masterMute.containsMouse ? PillTheme.cream : PillTheme.vermLit
                stroke: 1.8
            }

            MouseArea {
                id: masterMute
                anchors.centerIn: masterIcon
                width: 44 * root.s
                height: 44 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
                onWheel: (event) => {
                    root.stepVolume(root.sink?.audio, event.angleDelta.y > 0 ? 0.05 : -0.05);
                    event.accepted = true;
                }
            }

            Text {
                id: masterDevice
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 10 * root.s
                horizontalAlignment: Text.AlignHCenter
                text: root.deviceLabel(root.sink)
                color: PillTheme.faint
                font.family: PillTheme.font
                font.pixelSize: 10.5 * root.s
                elide: Text.ElideRight
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (event) => {
                    root.stepVolume(root.sink?.audio, event.angleDelta.y > 0 ? 0.05 : -0.05);
                    event.accepted = true;
                }
            }
        }

        Rectangle {
            id: appDivider
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: masterFader.right
            width: 1
            color: PillTheme.hair
        }

        Flickable {
            id: appFlick
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: appDivider.right
            anchors.leftMargin: 12 * root.s
            anchors.right: parent.right
            clip: true
            contentWidth: appRail.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    const maxX = Math.max(0, appFlick.contentWidth - appFlick.width);
                    appFlick.contentX = Math.max(0, Math.min(maxX, appFlick.contentX - delta));
                }
            }

            Row {
                id: appRail
                height: appFlick.height
                spacing: 8 * root.s

                Repeater {
                    model: root.appNodes

                    delegate: Item {
                        id: appFader
                        required property var modelData
                        width: 92 * root.s
                        height: appRail.height
                        readonly property real volume: appFader.modelData?.audio?.volume ?? 0
                        readonly property string iconName: MprisController.streamIconName(appFader.modelData)

                        PwObjectTracker { objects: [appFader.modelData] }

                        Image {
                            id: appIcon
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 30 * root.s
                            height: 30 * root.s
                            sourceSize.width: width
                            sourceSize.height: height
                            source: Quickshell.iconPath(appFader.iconName, "image-missing")
                            opacity: appFader.modelData?.audio?.muted ? 0.45 : 1
                        }

                        MouseArea {
                            id: appMute
                            anchors.centerIn: appIcon
                            width: 46 * root.s
                            height: 46 * root.s
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (appFader.modelData?.audio) appFader.modelData.audio.muted = !appFader.modelData.audio.muted
                            onWheel: (event) => {
                                root.stepVolume(appFader.modelData?.audio, event.angleDelta.y > 0 ? 0.05 : -0.05);
                                event.accepted = true;
                            }
                        }

                        Text {
                            id: appPct
                            anchors.top: appIcon.bottom
                            anchors.topMargin: 8 * root.s
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: appFader.modelData?.audio?.muted ? Translation.tr("off") : Math.round(appFader.volume * 100) + "%"
                            color: PillTheme.subtle
                            font.family: PillTheme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.DemiBold
                            font.features: ({ "tnum": 1 })
                        }

                        Rectangle {
                            id: appTrack
                            anchors.top: appPct.bottom
                            anchors.topMargin: 10 * root.s
                            anchors.bottom: appName.top
                            anchors.bottomMargin: 10 * root.s
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 8 * root.s
                            radius: width / 2
                            color: PillTheme.threadBg

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * Math.max(0, Math.min(1, appFader.volume))
                                radius: parent.radius
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: appFader.modelData?.audio?.muted ? PillTheme.vermDim : PillTheme.vermLit }
                                    GradientStop { position: 1.0; color: appFader.modelData?.audio?.muted ? PillTheme.vermDimDeep : PillTheme.vermBurn }
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: Math.max(0, Math.min(parent.height - height,
                                    (1 - Math.max(0, Math.min(1, appFader.volume))) * parent.height - height / 2))
                                width: 20 * root.s
                                height: 3 * root.s
                                radius: 2 * root.s
                                color: PillTheme.tickRest
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -12 * root.s
                                cursorShape: Qt.PointingHandCursor
                                function apply(mouseY) {
                                    if (!appFader.modelData?.audio)
                                        return;
                                    const localY = mouseY + 12 * root.s;
                                    appFader.modelData.audio.volume = 1 - Math.max(0, Math.min(1, localY / appTrack.height));
                                }
                                onPressed: (mouse) => apply(mouse.y)
                                onPositionChanged: (mouse) => { if (pressed) apply(mouse.y); }
                                onWheel: (event) => {
                                    root.stepVolume(appFader.modelData?.audio, event.angleDelta.y > 0 ? 0.05 : -0.05);
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            id: appName
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 8 * root.s
                            horizontalAlignment: Text.AlignHCenter
                            text: MprisController.compactStreamDisplayName(appFader.modelData, 18)
                            color: PillTheme.cream
                            font.family: PillTheme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (event) => {
                                root.stepVolume(appFader.modelData?.audio, event.angleDelta.y > 0 ? 0.05 : -0.05);
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.appNodes.length === 0
                text: Translation.tr("No apps playing audio")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 13 * root.s
            }
        }
    }

    Row {
        id: faderRow
        anchors.top: systemDeviceRow.bottom
        anchors.topMargin: 12 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 162 * root.s
        spacing: 0
        visible: root.view === "system"

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

    Row {
        id: systemDeviceRow
        visible: root.view === "system"
        anchors.top: divider.bottom
        anchors.topMargin: 10 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 18 * root.s

        Row {
            spacing: 8 * root.s
            DevicePickerChip {
                glyph: "speaker"
                open: root.openPicker === "out"
                tip: Translation.tr("Output device")
                onToggled: root.openPicker = root.openPicker === "out" ? "" : "out"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Output")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.Medium
            }
        }
        Row {
            spacing: 8 * root.s
            DevicePickerChip {
                glyph: "mic"
                open: root.openPicker === "in"
                tip: Translation.tr("Input device")
                onToggled: root.openPicker = root.openPicker === "in" ? "" : "in"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Input")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.Medium
            }
        }
    }

    MouseArea {
        id: wheelArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        enabled: root.view === "system"
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
