import QtQuick
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.modules.common

Item {
    id: root

    property real s: 1
    property string screenName: ""
    property bool outputAllowed: true
    property bool suppressed: false
    property bool trackSuppressed: false
    property bool expanded: false
    property bool compact: false
    property bool flashing: false
    property string kind: "volume"
    property bool armed: false
    property bool dirty: false
    property bool dirtyIntentional: false
    property bool cooling: false
    property int holdExtends: 0
    property bool intentionalTrackChangePending: false

    /**
     * The player the current flash speaks for. Normally the active source, but an
     * announce can point it at another player that just started, so a video over
     * your music still gets its own flash without stealing the surface.
     */
    property var pendingSubject: null
    readonly property var subject: pendingSubject ? pendingSubject : PillPlayers.active
    readonly property bool mediaFeedbackEnabled: root.outputAllowed
        && (Config.options?.bar?.pill?.osd ?? true)
        && (Config.options?.osd?.mediaEnabled ?? true)
    readonly property bool trackAllowed: (Config.options?.osd?.mediaEnabled ?? true)
        && !root.trackSuppressed
    readonly property bool subjectHas: subject !== null
    readonly property bool subjectPlaying: subjectHas && subject.isPlaying
    readonly property string subjectTitle: subjectHas ? PillPlayers.refineTitle(subject, subject.trackTitle || PillPlayers.labelOf(subject)) : ""
    readonly property string subjectArtist: subjectHas ? PillTheme.joinArtists(subject.trackArtists, subject.trackArtist) : ""
    readonly property string subjectIcon: subjectHas ? PillPlayers.appIconFor(subject) : ""

    /** Subject art, live so a cover that lands a beat after the title still resolves; the key forces a reload when a browser reuses one file path. */
    readonly property string liveArt: {
        if (!subjectHas)
            return "";
        var u = PillPlayers.artUrlFor(subject);
        if (!u)
            return "";
        return u.indexOf("file:") === 0 ? u + "#" + PillPlayers.keyFor(subject) : u;
    }

    /** Brightness is per-monitor; pick this pill's screen by name. */
    readonly property real brightness: {
        const m = (Brightness.monitors ?? []).find(x => x && x.screen && x.screen.name === root.screenName);
        return m ? m.brightness : 0;
    }
    property bool recordStarted: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real volume: sink && sink.audio ? Math.max(0, Math.min(1, sink.audio.volume)) : 0

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property real micVolume: source && source.audio ? Math.max(0, Math.min(1, source.audio.volume)) : 0

    readonly property real desiredW: kind === "workspace" ? Math.max(120 * s, wsIndicator.implicitWidth + 40 * s)
        : (kind === "track" ? 344 * s : (kind === "record" ? 256 * s : 248 * s))
    readonly property real desiredH: kind === "track" ? 64 * s : 44 * s

    /**
     * Active workspace name on this monitor. Any switch (Super+arrow,
     * Super+wheel, clicking a dot) changes it, so flashing the workspace OSD
     * here briefly morphs the pill open to show where you landed. The arm timer
     * swallows the initial populate, so login doesn't flash. Skipped while the
     * pill is expanded: the hover/surface pill already shows the live dots with
     * the active one marked, so the OSD would only be a redundant morph.
     */
    readonly property string activeWsName: {
        if (CompositorService.isNiri) {
            const ws = (NiriService.allWorkspaces ?? []).find(w => w.is_focused && w.output === root.screenName);
            return ws ? String(ws.idx) : "";
        }
        const mons = Hyprland.monitors?.values ?? [];
        for (let i = 0; i < mons.length; i++)
            if (mons[i].name === root.screenName)
                return mons[i].activeWorkspace ? mons[i].activeWorkspace.name : "";
        return "";
    }
    onActiveWsNameChanged: if (activeWsName.length > 0 && !expanded) flash("workspace");

    /**
     * Wait for the track to settle before flashing. Hovering the YouTube grid
     * autoplays a preview per thumbnail, so the active player's metadata churns
     * as the cursor moves; the settle timer collapses that storm into the one
     * track that actually sticks.
     */
    /**
     * Leading-edge throttle. The first change flashes at once so a real track
     * switch feels instant, then the cooldown mutes the burst that hovering the
     * YouTube grid throws off. Anything that lands during the cooldown, or while
     * the OSD is suppressed (a surface open, the pill pinned), stays `dirty` and
     * fires when the gate opens, so the stashed-player flash still replays.
     */
    function tryShow(intentional = root.dirtyIntentional) {
        if (cooling && !intentional)
            return;
        if (intentional) {
            cooling = false;
            cooldownTimer.stop();
        }
        if (flash("track", intentional)) {
            dirty = false;
            dirtyIntentional = false;
            cooling = true;
            cooldownTimer.restart();
        }
    }

    function flash(which, intentionalTrack = false) {
        // OSD face switched off: the standalone OnScreenDisplay panel owns the
        // flashes instead (ShellIiPanels hands it back when this key is false).
        if (!(Config.options?.bar?.pill?.osd ?? true))
            return false;
        if (which === "track" && !(Config.options?.osd?.mediaEnabled ?? true))
            return false;
        if (which === "track" && !intentionalTrack && !root.trackAllowed)
            return false;
        if (!outputAllowed || !armed || suppressed)
            return false;
        if (which === "track" && flashing && (kind === "volume" || kind === "brightness" || kind === "mic"))
            return false;
        if (which === "track")
            holdExtends = 0;
        kind = which;
        flashing = true;
        hideTimer.interval = (which === "battery" || which === "record") ? 2000 : 1800;
        hideTimer.restart();
        return true;
    }

    onSuppressedChanged: {
        if (suppressed) {
            hideTimer.stop();
            flashing = false;
        } else if (dirty) {
            tryShow();
        }
    }

    onOutputAllowedChanged: if (!outputAllowed) {
        dirty = false;
        dirtyIntentional = false;
        intentionalTrackChangePending = false;
        intentionalTrackFallback.stop();
        hideTimer.stop();
        flashing = false;
    }

    onTrackAllowedChanged: if (!trackAllowed) {
        dirty = false;
        dirtyIntentional = false;
        intentionalTrackChangePending = false;
        intentionalTrackFallback.stop();
        pendingSubject = null;
        if (kind === "track") {
            hideTimer.stop();
            flashing = false;
        }
    }

    onMediaFeedbackEnabledChanged: if (!mediaFeedbackEnabled) {
        dirty = false;
        dirtyIntentional = false;
        intentionalTrackChangePending = false;
        intentionalTrackFallback.stop();
        pendingSubject = null;
        if (kind === "track") {
            hideTimer.stop();
            flashing = false;
        }
    }

    Timer {
        id: intentionalTrackFallback
        interval: 1200
        onTriggered: {
            if (!root.intentionalTrackChangePending)
                return;
            root.intentionalTrackChangePending = false;
            root.pendingSubject = PillPlayers.active;
            root.dirty = true;
            root.dirtyIntentional = true;
            root.tryShow(true);
        }
    }

    /** A track announce that lost to live hardware feedback replays once the bar clears. */
    onFlashingChanged: if (!flashing && dirty) tryShow()

    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: cooldownTimer
        interval: 1500
        onTriggered: {
            root.cooling = false;
            if (root.dirty)
                root.tryShow();
        }
    }

    /**
     * Hold a track flash open until its cover decodes, so a cold remote thumbnail
     * that arrives after the base window still gets seen. Capped so a dead art url
     * never pins the OSD.
     */
    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: {
            if (root.kind === "track" && cover.status !== Image.Ready && root.liveArt.length > 0 && root.holdExtends < 5) {
                root.holdExtends++;
                hideTimer.interval = 350;
                hideTimer.restart();
            } else {
                root.flashing = false;
            }
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }

    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        function onVolumesChanged() { root.flash("volume"); }
        function onMutedChanged() { root.flash("volume"); }
    }

    Connections {
        target: root.source && root.source.audio ? root.source.audio : null
        function onVolumesChanged() { root.flash("mic"); }
        function onMutedChanged() { root.flash("mic"); }
    }

    Connections {
        target: PillPlayers
        function onAnnounce(player) {
            const intentional = root.intentionalTrackChangePending;
            if (!root.mediaFeedbackEnabled
                    || (!root.trackAllowed && !intentional))
                return;
            if (intentional) {
                intentionalTrackFallback.stop();
                root.intentionalTrackChangePending = false;
            }
            root.pendingSubject = player;
            root.dirty = true;
            root.dirtyIntentional = intentional;
            root.tryShow(intentional);
        }
    }

    Connections {
        target: GlobalStates
        function onOsdMediaActionTriggered(action: string) {
            if (!root.mediaFeedbackEnabled)
                return;
            if (action === "next" || action === "previous") {
                root.intentionalTrackChangePending = true;
                intentionalTrackFallback.restart();
                return;
            }
            root.pendingSubject = PillPlayers.active;
            root.dirty = true;
            root.dirtyIntentional = true;
            root.tryShow(true);
        }
    }

    Connections {
        target: PillBattery
        enabled: PillBattery.present
        function onChargingChanged() {
            if (PillBattery.charging)
                root.flash("battery");
        }
    }

    Connections {
        target: RecorderStatus
        function onIsRecordingChanged() {
            root.recordStarted = RecorderStatus.isRecording;
            root.flash("record");
        }
    }

    /**
     * Brightness has no change signal of its own; the per-monitor value is a
     * binding, so flash on its transitions. Skip the first settle after load,
     * where it goes 0 → real value.
     */
    property bool _brightnessArmed: false
    Timer {
        interval: 1200
        running: true
        onTriggered: root._brightnessArmed = true
    }
    onBrightnessChanged: if (root._brightnessArmed) root.flash("brightness")

    Item {
        id: volRow
        anchors.fill: parent
        opacity: root.kind === "volume" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

        GlyphIcon {
            id: volGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 13 : 17) * root.s
            height: width
            name: root.muted ? "speaker-off" : "speaker"
            color: root.muted ? PillTheme.dim : PillTheme.iconDim
            stroke: 1.7
        }

        Text {
            id: volPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 26 : 32) * root.s
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.volume * 100) + "%"
            color: root.muted ? PillTheme.dim : PillTheme.cream
            font.family: PillTheme.font
            font.pixelSize: (root.compact ? 9.5 : 11) * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: volGlyph.right
            anchors.leftMargin: (root.compact ? 6 : 12) * root.s
            anchors.right: volPct.left
            anchors.rightMargin: (root.compact ? 6 : 12) * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: (root.compact ? 3 : 4) * root.s
            radius: height / 2
            color: PillTheme.threadBg
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.volume
                radius: parent.radius
                color: root.muted ? PillTheme.vermDim : PillTheme.vermLit
                Behavior on width { NumberAnimation { duration: PillMotion.fast } }
                Behavior on color { ColorAnimation { duration: PillMotion.fast } }
            }
        }
    }

    Item {
        id: micRow
        anchors.fill: parent
        opacity: root.kind === "mic" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

        GlyphIcon {
            id: micGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 13 : 17) * root.s
            height: width
            name: root.micMuted ? "mic-off" : "mic"
            color: root.micMuted ? PillTheme.dim : PillTheme.iconDim
            stroke: 1.7
        }

        Text {
            id: micPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 26 : 32) * root.s
            horizontalAlignment: Text.AlignRight
            text: root.micMuted ? "off" : Math.round(root.micVolume * 100) + "%"
            color: root.micMuted ? PillTheme.dim : PillTheme.cream
            font.family: PillTheme.font
            font.pixelSize: (root.compact ? 9.5 : 11) * root.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }

        Rectangle {
            anchors.left: micGlyph.right
            anchors.leftMargin: (root.compact ? 6 : 12) * root.s
            anchors.right: micPct.left
            anchors.rightMargin: (root.compact ? 6 : 12) * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: (root.compact ? 3 : 4) * root.s
            radius: height / 2
            color: PillTheme.threadBg
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.micVolume
                radius: parent.radius
                color: root.micMuted ? PillTheme.vermDim : PillTheme.vermLit
                Behavior on width { NumberAnimation { duration: PillMotion.fast } }
                Behavior on color { ColorAnimation { duration: PillMotion.fast } }
            }
        }
    }

    Item {
        id: trackRow
        anchors.fill: parent
        opacity: root.kind === "track" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

        ClippingRectangle {
            id: coverBox
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            // Fit inside whatever height the host grants (bar mode keeps the
            // bar's own geometry, slightly shorter than the capsule face).
            width: root.compact
                ? Math.min(22 * root.s, trackRow.height)
                : Math.min(44 * root.s, trackRow.height - 8 * root.s)
            height: width
            radius: (root.compact ? 6 : 9) * root.s
            color: PillTheme.tileBg

            Image {
                id: cover
                anchors.fill: parent
                source: root.liveArt
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: String(source).indexOf("file:") !== 0
                opacity: status === Image.Ready ? 1 : 0
                /** Art that arrives late still earns a moment on screen, so a cover
                 *  decoded near the end of the flash is actually seen. */
                onStatusChanged: if (status === Image.Ready && root.flashing && root.kind === "track") {
                    hideTimer.interval = 1300;
                    hideTimer.restart();
                }
            }
            GlyphIcon {
                anchors.centerIn: parent
                width: parent.width * 0.42
                height: width
                name: "music"
                color: PillTheme.subtle
                visible: cover.status !== Image.Ready
            }

            /** The source's own app icon, sat as a small badge on the art corner. */
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 3 * root.s
                width: 18 * root.s
                height: 18 * root.s
                radius: width / 2
                color: Qt.alpha(PillTheme.cardBot, 0.8)
                visible: !root.compact && srcIcon.status === Image.Ready

                Image {
                    id: srcIcon
                    anchors.centerIn: parent
                    width: 12 * root.s
                    height: 12 * root.s
                    sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    source: root.subjectIcon
                }
            }
        }

        GlyphIcon {
            id: trackCtrl
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 12 : 18) * root.s
            height: width
            name: root.subjectPlaying ? "play" : "pause"
            color: root.subjectPlaying ? PillTheme.vermLit : PillTheme.iconDim
        }

        Column {
            anchors.left: coverBox.right
            anchors.leftMargin: (root.compact ? 6 : 12) * root.s
            anchors.right: trackCtrl.left
            anchors.rightMargin: (root.compact ? 4 : 12) * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * root.s

            Text {
                width: parent.width
                text: root.subjectHas ? root.subjectTitle : "Nothing playing"
                color: PillTheme.cream
                font.family: PillTheme.font
                font.pixelSize: (root.compact ? 9.5 : 14) * root.s
                font.weight: Font.DemiBold
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.subjectArtist
                color: PillTheme.dim
                font.family: PillTheme.font
                font.pixelSize: 11 * root.s
                maximumLineCount: 1
                elide: Text.ElideRight
                visible: !root.compact && text.length > 0
            }
        }
    }

    Item {
        id: brightRow
        anchors.fill: parent
        opacity: root.kind === "brightness" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

        GlyphIcon {
            id: brightGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 13 : 17) * root.s
            height: width
            name: "sun"
            color: PillTheme.iconDim
            stroke: 1.7
        }

        Text {
            id: brightPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 26 : 32) * root.s
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.brightness * 100) + "%"
            color: PillTheme.cream
            font.family: PillTheme.font
            font.pixelSize: (root.compact ? 9.5 : 11) * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: brightGlyph.right
            anchors.leftMargin: (root.compact ? 6 : 12) * root.s
            anchors.right: brightPct.left
            anchors.rightMargin: (root.compact ? 6 : 12) * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: (root.compact ? 3 : 4) * root.s
            radius: height / 2
            color: PillTheme.threadBg
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.brightness
                radius: parent.radius
                color: PillTheme.vermLit
                Behavior on width { NumberAnimation { duration: PillMotion.fast } }
            }
        }
    }

    Item {
        id: batteryRow
        anchors.fill: parent
        opacity: root.kind === "battery" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

        GlyphIcon {
            id: battGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 13 : 17) * root.s
            height: width
            name: "bolt"
            color: PillTheme.flameGlow
            stroke: 1.7
        }

        Text {
            id: battPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 30 : 40) * root.s
            horizontalAlignment: Text.AlignRight
            text: PillBattery.pct + "%"
            color: PillTheme.cream
            font.family: PillTheme.font
            font.pixelSize: (root.compact ? 9.5 : 11) * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: battGlyph.right
            anchors.leftMargin: (root.compact ? 6 : 12) * root.s
            anchors.right: battPct.left
            anchors.rightMargin: (root.compact ? 6 : 12) * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: (root.compact ? 3 : 4) * root.s
            radius: height / 2
            color: PillTheme.threadBg
            clip: true

            Rectangle {
                id: battFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * PillBattery.frac
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: PillTheme.vermDeep }
                    GradientStop { position: 1.0; color: PillTheme.flameGlow }
                }
                Behavior on width { NumberAnimation { duration: PillMotion.fast } }

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 34 * root.s
                    color: "transparent"
                    // Cream-derived so the charge sweep stays legible on a light
                    // palette; the literal warm white it replaced was invisible
                    // against a bright generated scheme.
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.alpha(PillTheme.cream, 0) }
                        GradientStop { position: 0.5; color: Qt.alpha(PillTheme.cream, 0.33) }
                        GradientStop { position: 1.0; color: Qt.alpha(PillTheme.cream, 0) }
                    }

                    NumberAnimation on x {
                        from: -34 * root.s
                        to: battFill.width
                        duration: 1200
                        loops: Animation.Infinite
                        running: root.kind === "battery" && PillBattery.charging
                    }
                }
            }
        }
    }

    Item {
        id: workspaceRow
        anchors.fill: parent
        opacity: root.kind === "workspace" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

        PillWorkspaces {
            id: wsIndicator
            anchors.centerIn: parent
            screenName: root.screenName
            s: root.s
            gap: (root.compact ? 5 : 8) * root.s
            enabled: false
        }
    }

    Item {
        id: recordRow
        anchors.fill: parent
        opacity: root.kind === "record" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

        Rectangle {
            id: recGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: (root.compact ? 9 : 13) * root.s
            height: width
            radius: width / 2
            color: root.recordStarted ? PillTheme.verm : PillTheme.dim

            SequentialAnimation on opacity {
                running: root.recordStarted && root.kind === "record"
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.left: recGlyph.right
            anchors.leftMargin: (root.compact ? 8 : 13) * root.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.compact
                ? (root.recordStarted ? "REC" : "Stopped")
                : (root.recordStarted ? "Recording started" : "Recording stopped")
            color: PillTheme.cream
            font.family: PillTheme.font
            font.pixelSize: (root.compact ? 9.5 : 11.5) * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
