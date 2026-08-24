pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs
import qs.services
import qs.modules.common

/**
 * The pill body. One element carries every state. Width/height driven by `mode`
 * (rest, hover/pinned, and later each open surface) with a no-overshoot easing so
 * surfaces grow out of the pill in place. Faces are stacked absolutely and
 * cross-fade.
 *
 * Hover comes from a passive HoverHandler on the host window and pin from a
 * passive TapHandler, so neither swallows pointer events from the faces stacked
 * above: workspace dots, the clock target and the status icons get their own
 * clicks.
 */
Item {
    id: pill

    property real s: 1
    property string screenName: ""
    property var barWindow
    property string surface: ""

    property bool hovered: false
    property bool pinned: false
    property bool forcePinned: false

    readonly property bool held: pinned || forcePinned
    readonly property bool surfaceOpen: surface.length > 0
    property bool hoverLatch: false

    /**
     * Bar mode parks the pill in its expanded hover row permanently: every
     * trigger sits in the open, no hover dance needed. Semantically identical
     * to being hovered forever, so the rest face simply never shows.
     */
    readonly property bool barMode: Config.options?.bar?.pill?.barMode ?? false
    readonly property bool expanded: surfaceOpen || held || hoverLatch || barMode

    readonly property bool hasMedia: PillPlayers.has

    signal requestSurface(string name)
    signal requestClose()

    /** Forwarded up so the root Scope can host the tray menu's own window. */
    signal trayMenuRequested(var item, real anchorX)
    property bool trayMenuOpen: false

    readonly property real restW: 160 * s
    readonly property real restH: 38 * s
    readonly property real hoverPad: 20 * s
    readonly property real hoverW: hoverRow.implicitWidth + 2 * hoverPad
    readonly property real hoverH: 58 * s
    readonly property real gameH: 34 * s
    readonly property real gameW: barWindow ? barWindow.width : 1920
    /**
     * Corners follow the shared island skin instead of two hardcoded constants,
     * so Settings › Ricelin › Island skin governs the pill exactly as it governs
     * the dock, sidebars and search. PillTheme applies the global style's
     * character on top (square ZZZ sharpens; every soft style keeps Ricelin).
     */
    readonly property real restCorner: PillTheme.cardCorner * s
    readonly property real openCorner: PillTheme.openCorner * s

    readonly property real powerW: 330 * s
    readonly property real powerH: 150 * s
    readonly property real mediaW: (PillPlayers.pickable.length > 1 ? 460 : 390) * s
    readonly property real mediaH: 150 * s
    readonly property real batteryW: 316 * s
    readonly property real toastW: 342 * s
    readonly property real sysmonW: 392 * s
    readonly property real clipboardW: 360 * s
    readonly property real clipboardH: 332 * s
    readonly property real glanceW: 470 * s
    readonly property real glanceH: 178 * s
    readonly property real launcherW: 360 * s
    readonly property real launcherH: 332 * s
    readonly property real recorderW: 330 * s
    readonly property real recorderH: 176 * s

    /**
     * Per-surface config gates for the two optional faces. The core surfaces
     * (power, media, calendar, link, mixer, battery) always exist because their
     * triggers are the pill's own furniture; these two are additions on top of
     * the stock hover row, so each can be switched off from Settings → Bar.
     */
    readonly property bool sysmonEnabled: Config.options?.bar?.pill?.surfaces?.sysmon ?? true
    readonly property bool clipboardEnabled: Config.options?.bar?.pill?.surfaces?.clipboard ?? true
    readonly property bool glanceEnabled: Config.options?.bar?.pill?.surfaces?.glance ?? true
    readonly property bool launcherEnabled: Config.options?.bar?.pill?.surfaces?.launcher ?? true
    readonly property bool recorderEnabled: Config.options?.bar?.pill?.surfaces?.recorder ?? false

    /**
     * Hover-row furniture gates. Each stock module in the expanded row can be
     * switched off individually; surface-bound icons follow surfaces.* above.
     */
    readonly property var hoverModules: Config.options?.bar?.pill?.modules

    // Icon size for the pill's furniture, snapped to whole pixels so the vector
    // glyphs rasterise crisp. Hit areas grow with it.
    readonly property real iconPx: Math.round((Config.options?.bar?.pill?.iconSize ?? 17) * s)

    // Toasts off hands notifications back to the standalone popup panel
    // (ShellIiPanels re-enables it), so nothing goes silent.
    function outputEnabled(list: var): bool {
        if (!list || list.length === 0)
            return true
        if (screenName.length > 0 && list.includes(screenName))
            return true
        const currentNames = Quickshell.screens.map(screen => screen?.name ?? "")
        return !list.some(name => currentNames.includes(name))
    }

    readonly property bool toastOutputEnabled: pill.outputEnabled(Config.options?.notifications?.screenList ?? [])
    readonly property bool osdOutputEnabled: pill.outputEnabled(Config.options?.osd?.screenList ?? [])
    readonly property bool toastActive: (Config.options?.bar?.pill?.toasts ?? true)
        && pill.toastOutputEnabled && PillNotifs.popups.length > 0
    readonly property bool osdActive: pill.osdOutputEnabled && osd.flashing
    readonly property bool compactAnnounces: Config.options?.bar?.pill?.compactAnnounces ?? false

    /**
     * Latch-once lazy load. Every surface sleeps in an inactive Loader until its
     * first open; the size and ame thunks below resolve items through here. The
     * ordering is the trick: flip `active` before any read of the loader, so the
     * calling binding never has the loader registered as a dep when the flip fires
     * mid-evaluation (that read-then-write would be a binding loop). The write is
     * idempotent and the Loader loads synchronously, so a first open reads the real
     * implicitHeight in the same evaluation and the morph target is exact.
     */
    function surfaceItem(ld) {
        ld.active = true;
        return ld.item;
    }

    /**
     * Single source of truth for every morphing surface, keyed by its `surface`
     * string. Each entry owns the surface's target size (a thunk so the geometry
     * it reads registers as a live dep of targetSize) and a thunk resolving the
     * surface item Ame anchors to while it is open. Adding a surface is one entry
     * here plus its Loader — no parallel ternary chains to keep in lockstep.
     */
    readonly property var surfaces: ({
        power:    { size: () => { surfaceItem(ldPower); return Qt.size(powerW, powerH); }, ame: () => surfaceItem(ldPower) },
        media:    { size: () => { surfaceItem(ldMedia); return Qt.size(mediaW, mediaH); }, ame: () => surfaceItem(ldMedia) },
        battery:  { size: () => Qt.size(batteryW, surfaceItem(ldBattery).implicitHeight + 26 * s), ame: () => surfaceItem(ldBattery) },
        calendar: { size: () => { const it = surfaceItem(ldCalendar); return Qt.size((it.implicitWidth > 0 ? it.implicitWidth : 282 * s) + 36 * s, it.implicitHeight + 32 * s); }, ame: () => surfaceItem(ldCalendar) },
        link:     { size: () => { const it = surfaceItem(ldLink); return Qt.size(it.desiredW, it.implicitHeight + 26 * s); }, ame: () => surfaceItem(ldLink) },
        mixer:    { size: () => Qt.size(93 * Math.max(4, surfaceItem(ldMixer).faderCount) * s, mixerH), ame: () => surfaceItem(ldMixer) },
        sysmon:   { size: () => Qt.size(sysmonW, surfaceItem(ldSysmon).implicitHeight + 33 * s), ame: () => surfaceItem(ldSysmon) },
        clipboard: { size: () => { surfaceItem(ldClipboard); return Qt.size(clipboardW, clipboardH); }, ame: () => surfaceItem(ldClipboard) },
        glance:   { size: () => { surfaceItem(ldGlance); return Qt.size(glanceW, glanceH); }, ame: () => surfaceItem(ldGlance) },
        launcher: { size: () => { surfaceItem(ldLauncher); return Qt.size(launcherW, launcherH); }, ame: () => surfaceItem(ldLauncher) },
        recorder: { size: () => { surfaceItem(ldRecorder); return Qt.size(recorderW, recorderH); }, ame: () => surfaceItem(ldRecorder) }
    })

    readonly property real mixerH: 214 * s

    /**
     * Subview the link surface should land on when next opened. The wifi glance
     * drills straight to the network list; the inbox glance lands on main. Reset
     * once the surface closes.
     */
    property string linkInitialView: "main"
    onSurfaceChanged: if (surface !== "link") linkInitialView = "main"

    // The wide game face is an explicit manual mode. Automatic fullscreen
    // detection only hides the resting pill; it must never stretch the pill
    // across the display merely because an app entered fullscreen.
    readonly property bool manualGameFace: GameMode.manuallyActivated

    /**
     * A fullscreen window on this pill's active workspace hides the resting
     * faces — classic-bar parity: top-layer bars get covered by the
     * compositor, but the pill's Overlay layer never is, so it opts out
     * itself. Only the resting faces: transient OSD flashes still play over a
     * game, because a track change or a volume keypress is exactly the feedback
     * the game cannot give you. Toasts and open surfaces still show.
     */
    readonly property bool fsCovered: {
        if (!CompositorService.isNiri)
            return GameMode.hasAnyFullscreenWindow;
        const wins = NiriService.windows ?? [];
        for (const w of wins) {
            const ws = NiriService.workspaces?.[w.workspace_id];
            if (!(ws?.is_active ?? false))
                continue;
            if (screenName.length > 0 && ws.output !== screenName)
                continue;
            // In niri a fullscreen window covers the monitor only while it
            // is the focused tile. Scrolling to another window in the same
            // workspace unfocuses the fullscreen window without changing its
            // size, so without this focus check the pill stays hidden even
            // though the game no longer covers the screen.
            if (!w.is_focused)
                continue;
            if (GameMode.isWindowFullscreen(w))
                return true;
        }
        return false;
    }
    readonly property bool fsHide: fsCovered
        && (mode === "rest" || mode === "hover" || mode === "game")

    opacity: fsHide ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity {
        NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard }
    }

    /**
     * Mode ladder. An open surface always wins; explicit manual Game Mode can
     * dock the pill into its wide face; automatic fullscreen only hides the
     * resting pill. Transient feedback still appears unless the pill is held.
     */
    readonly property string mode: surfaceOpen && surfaces[surface] !== undefined ? surface
        : (manualGameFace && !fsCovered ? "game"
        : (osdActive && !held ? "osd"
        : (toastActive && !held ? "toast"
        : (expanded ? "hover" : "rest"))))

    onSurfaceOpenChanged: if (surfaceOpen) pinned = false

    QtObject {
        id: clock
        readonly property var loc: Qt.locale()
        readonly property var now: sysClock.date
        readonly property string timeFormat: (PillTheme.time12h ? "h:mm" : "HH:mm")
            + (PillTheme.clockSeconds ? ":ss" : "")
            + (PillTheme.time12h ? " AP" : "")
        readonly property string hhmm: Qt.formatTime(now, timeFormat)
        readonly property string date: loc.toString(now, "ddd d MMM")
    }

    SystemClock {
        id: sysClock
        precision: PillTheme.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property bool compactAnnounceMode: compactAnnounces && (mode === "osd" || mode === "toast")
    property real morphRadius: (mode === "rest" || mode === "hover" || mode === "game" || compactAnnounceMode)
        ? restCorner : openCorner

    /**
     * Target geometry for the non-surface morph modes. Surface sizes come from
     * the `surfaces` descriptor; these are the pill's own modes that have no
     * surface item. Thunks so the properties they read register as live deps.
     */
    /**
     * Transient feedback normally receives enough room for its complete card.
     * Compact announces use the exact resting capsule geometry instead, in both
     * normal and bar mode, and simplify their content to what can fit there.
     */
    readonly property var modeSize: ({
        hover: () => Qt.size(hoverW, hoverH),
        game: () => Qt.size(gameW, gameH),
        osd: () => compactAnnounces ? Qt.size(restW, restH) : Qt.size(osd.desiredW, osd.desiredH),
        toast: () => {
            if (compactAnnounces)
                return Qt.size(restW, restH);
            const th = toastLoader.item ? toastLoader.item.implicitHeight + 24 * s : restH;
            return Qt.size(toastW, th);
        }
    })

    readonly property size targetSize: {
        const sf = surfaces[mode];
        if (sf)
            return sf.size();
        const f = modeSize[mode];
        return f ? f() : Qt.size(Math.max(restW, restRow.implicitWidth + 36 * s), restH);
    }

    /**
     * Snap the morph target to whole pixels. The pill is centred as
     * (screenWidth - width) / 2, so an odd or fractional width lands the whole
     * body on a half pixel and every glyph inside it renders blurred.
     */
    readonly property real targetW: Math.round(targetSize.width / 2) * 2
    readonly property real targetH: Math.round(targetSize.height)

    width: targetW
    height: targetH

    /**
     * How settled the pill is into its target geometry: 0 while the morph is far
     * away, 1 once it arrives. Content opacities key off this, not their own
     * timers, so a face fades in as the pill reaches full size, never over a
     * half-grown pill.
     */
    readonly property real morphCloseness: {
        const d = Math.max(Math.abs(width - targetW), Math.abs(height - targetH));
        return 1 - Math.min(1, d / (110 * s));
    }

    /**
     * Gate the soul bead until the hover morph has arrived and its icons exist.
     * Fire it earlier and the bead aims at anchors that aren't laid out yet.
     * Latched so small width changes inside hover don't flicker the bead off.
     */
    property bool hoverSoulGate: false
    readonly property bool hoverArrived: mode === "hover" && morphCloseness > 0.55
    onHoverArrivedChanged: if (hoverArrived) hoverSoulGate = true

    /**
     * Rest and hover sit a few dozen pixels apart, so the full morph is nearly
     * all settle tail on that hop and reads sluggish. Both endpoints in the
     * rest/hover pair get the shorter glide; every real surface morph keeps the
     * full duration.
     */
    property string lastMode: "rest"
    property bool hoverHop: false

    onModeChanged: {
        hoverHop = (mode === "hover" || mode === "rest") && (lastMode === "hover" || lastMode === "rest");
        lastMode = mode;
        if (mode !== "hover") {
            hoverSoulGate = false;
            soulTarget = "";
            soulWsIndex = -1;
        }
    }
    onHoverSoulGateChanged: if (hoverSoulGate) kanjiFlashAnim.restart()

    property string soulTarget: ""
    property int soulWsIndex: -1
    property real kanjiFlash: 0

    /**
     * Bespoke snap-and-settle timing (a fast strike, a slower decay) that no
     * motion token expresses, so the literals stay but are scaled by the shared
     * multiplier — otherwise the flash keeps firing with animations disabled.
     */
    SequentialAnimation {
        id: kanjiFlashAnim
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 1; duration: Math.round(90 * PillMotion.mult); easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 0; duration: Math.round(320 * PillMotion.mult); easing.type: Easing.OutCubic }
    }

    Behavior on width { NumberAnimation { duration: pill.hoverHop ? PillMotion.glide : PillMotion.morph; easing.type: PillMotion.easeMorph; easing.bezierCurve: PillMotion.morphCurve } }
    Behavior on height { NumberAnimation { duration: pill.hoverHop ? PillMotion.glide : PillMotion.morph; easing.type: PillMotion.easeMorph; easing.bezierCurve: PillMotion.morphCurve } }
    Behavior on morphRadius { NumberAnimation { duration: pill.hoverHop ? PillMotion.glide : PillMotion.morph; easing.type: PillMotion.easeMorph; easing.bezierCurve: PillMotion.morphCurve } }

    Rectangle {
        id: bud
        readonly property bool shown: pill.mode === "hover" && pill.hasMedia
        property real budR: (budArea.containsMouse ? 15 : 12) * pill.s
        width: budR * 2
        height: budR * 2
        radius: budR
        x: pill.width - budR
        anchors.verticalCenter: parent.verticalCenter
        visible: opacity > 0.01
        opacity: shown ? 1 : 0
        border.width: 1
        border.color: PillTheme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(PillTheme.cardTop, PillTheme.pillOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(PillTheme.cardBot, PillTheme.pillOpacity) }
        }
        Behavior on budR { NumberAnimation { duration: PillMotion.fast; easing.type: PillMotion.easeStandard } }
        Behavior on opacity { NumberAnimation { duration: PillMotion.standard } }

        Canvas {
            id: budBead
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 3 * pill.s
            width: 18 * pill.s
            height: 18 * pill.s
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                const R = (budArea.containsMouse ? 5.2 : 4) * pill.s;
                const hg = ctx.createRadialGradient(c - R * 0.32, c - R * 0.38, 0, c, c, R);
                hg.addColorStop(0, PillTheme.flameInk);
                hg.addColorStop(0.55, PillTheme.hex(PillTheme.vermLit));
                hg.addColorStop(0.92, PillTheme.hex(PillTheme.verm));
                hg.addColorStop(1, PillTheme.flameEmber);
                ctx.beginPath();
                ctx.arc(c, c, R, 0, 7);
                ctx.fillStyle = hg;
                ctx.fill();
                ctx.beginPath();
                ctx.ellipse(c - R * 0.62, c - R * 0.66, R * 0.6, R * 0.36);
                ctx.fillStyle = "rgba(255,246,240,0.6)";
                ctx.fill();
            }
        }

        MouseArea {
            id: budArea
            anchors.fill: parent
            enabled: bud.shown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("media")
            onContainsMouseChanged: budBead.requestPaint()
        }
    }

    /**
     * Frosted glass under the pill, from the same shared island skin. The card
     * gradient above is only translucent when the user lowers the pill opacity,
     * so without a backdrop a low opacity reads as raw see-through rather than
     * glass — exactly the reason IslandPanel grew this path.
     *
     * The wallpaper is drawn at screen scale and offset by the pill's position
     * inside its screen-sized overlay window, so the blur stays registered with
     * the desktop while the pill morphs across the top of the screen. Masked to
     * the live morph radius so it never squares off mid-animation.
     */
    Item {
        id: glass
        anchors.fill: parent
        z: -1

        readonly property bool active: pill.visible
            && PillTheme.islandGlass
            && Appearance.effectsEnabled
            && PillTheme.pillOpacity < 0.999

        visible: active
        layer.enabled: active
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: glass.width
                height: glass.height
                radius: body.radius
            }
        }

        Image {
            id: glassWallpaper
            x: -pill.x
            y: -pill.y
            width: pill.barWindow ? pill.barWindow.width : 1920
            height: pill.barWindow ? pill.barWindow.height : 1080
            visible: glass.active && status === Image.Ready
            source: glass.active ? Wallpapers.effectiveWallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            sourceSize.width: width
            sourceSize.height: height

            layer.enabled: glass.active
            layer.effect: MultiEffect {
                source: glassWallpaper
                anchors.fill: source
                saturation: 0.15
                blurEnabled: true
                blurMax: 64
                blur: PillTheme.islandGlassBlur
            }
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent

        /**
         * Corner flatness rides the morph curve so docking into the game bar
         * squares the corners as one continuous shape change instead of a snap.
         */
        property real gameFlat: pill.mode === "game" ? 1 : 0
        Behavior on gameFlat { NumberAnimation { duration: PillMotion.morph; easing.type: PillMotion.easeMorph; easing.bezierCurve: PillMotion.morphCurve } }

        radius: pill.morphRadius
        topLeftRadius: pill.morphRadius * (1 - gameFlat)
        topRightRadius: pill.morphRadius * (1 - gameFlat)
        bottomLeftRadius: pill.morphRadius * (1 - gameFlat)
        bottomRightRadius: pill.morphRadius * (1 - gameFlat)
        border.width: 1
        border.color: PillTheme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(PillTheme.cardTop, PillTheme.pillOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(PillTheme.cardBot, PillTheme.pillOpacity) }
        }

        // Shared island skin: the user's drop-shadow switch owns the pill too.
        // Keeping a layer allocated for a disabled shadow would still cost a
        // full-surface texture on every morph frame, so gate the layer itself.
        layer.enabled: PillTheme.islandShadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, PillTheme.shadowOpacity)
            shadowBlur: 0.7
            shadowVerticalOffset: 3 * pill.s
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: body.radius * 0.6
            anchors.rightMargin: body.radius * 0.6
            height: 1
            visible: PillTheme.islandSheen
            color: PillTheme.sheen
        }
    }

    /**
     * Rest anchor for Ame: the 時 kanji centre. The idle outline condenses into
     * the bead here before it moves.
     */
    readonly property point wakePoint: {
        void pill.width;
        void pill.height;
        return restKanji.mapToItem(pill, restKanji.width / 2, restKanji.height / 2);
    }

    /**
     * Bead target while hovered. soulTarget is a sticky key written by the hover
     * sources: the bead parks on the last focused dot or icon and glides to the
     * next, so crossing a gap between targets doesn't snap it back to the active
     * workspace. Pill geometry is voided so the anchor follows the hover morph.
     */
    readonly property point soulPoint: {
        void pill.width;
        void pill.height;
        const drop = 12 * pill.s;
        if (soulTarget === "wifi")
            return wifiIcon.mapToItem(pill, wifiIcon.width / 2, wifiIcon.height + drop * 0.55);
        if (soulTarget === "battery")
            return batteryIcon.mapToItem(pill, batteryIcon.width / 2, batteryIcon.height + drop * 0.55);
        if (soulTarget === "inbox")
            return inboxIcon.mapToItem(pill, inboxIcon.width / 2, inboxIcon.height + drop * 0.55);
        if (soulTarget === "mixer")
            return mixerIcon.mapToItem(pill, mixerIcon.width / 2, mixerIcon.height + drop * 0.55);
        if (soulTarget === "glance")
            return glanceIcon.mapToItem(pill, glanceIcon.width / 2, glanceIcon.height + drop * 0.55);
        if (soulTarget === "launcher")
            return launcherIcon.mapToItem(pill, launcherIcon.width / 2, launcherIcon.height + drop * 0.55);
        if (soulTarget === "recorder")
            return recorderIcon.mapToItem(pill, recorderIcon.width / 2, recorderIcon.height + drop * 0.55);
        if (soulTarget === "power")
            return powerIcon.mapToItem(pill, powerIcon.width / 2, powerIcon.height + drop * 0.55);
        if (soulTarget === "clipboard")
            return clipboardIcon.mapToItem(pill, clipboardIcon.width / 2, clipboardIcon.height + drop * 0.55);
        if (soulTarget === "sysmon")
            return sysmonIcon.mapToItem(pill, sysmonIcon.width / 2, sysmonIcon.height + drop * 0.55);
        if (soulTarget === "sidebarLeft")
            return sidebarLeftIcon.mapToItem(pill, sidebarLeftIcon.width / 2, sidebarLeftIcon.height + drop * 0.55);
        if (soulTarget === "sidebarRight")
            return sidebarRightIcon.mapToItem(pill, sidebarRightIcon.width / 2, sidebarRightIcon.height + drop * 0.55);
        if (soulTarget === "ws" && soulWsIndex >= 0) {
            void ws.activeIndex;
            void ws.width;
            const p = ws.mapToItem(pill, ws.slotCenterX(soulWsIndex), ws.height / 2);
            return Qt.point(p.x, p.y + drop);
        }
        return ws.mapToItem(pill, ws.activeDotPoint.x, ws.activeDotPoint.y + drop);
    }

    /**
     * Which open surface owns Ame's anchor. Each surface exports its own
     * `ameForm`/`amePoint`; the pill picks the open surface's `ame` from the
     * descriptor and maps it. Null = nothing open, so Ame falls back to the
     * pill's own hover/wake anchor.
     */
    readonly property var ameSurface: (surfaceOpen && surfaces[surface] !== undefined)
        ? surfaces[surface].ame() : null

    Ame {
        id: ame
        anchors.fill: parent
        s: pill.s
        wake: pill.wakePoint
        wickDir: -1
        // Surface forms (caret, anchors) are functional and always allowed; the
        // free-roaming hover bead is the part users may switch off.
        form: pill.ameSurface ? pill.ameSurface.ameForm
            : (pill.mode === "hover" && pill.hoverSoulGate && (Config.options?.bar?.pill?.soul?.enable ?? true) ? "soul" : "off")
        point: pill.ameSurface
            ? Qt.point(pill.ameSurface.x + pill.ameSurface.amePoint.x,
                       pill.ameSurface.y + pill.ameSurface.amePoint.y)
            : (pill.mode === "hover" ? pill.soulPoint : pill.wakePoint)
    }

    /**
     * Extra input width past the pill's right edge while the media bud sticks out
     * there, so the window mask covers the bud's outer half. pill.hovered is fed
     * by a window-level HoverHandler: pointer events only exist inside the input
     * mask, so "window hovered" means "pointer over the pill (or bud)". That
     * sidesteps the per-item hover flicker the child MouseAreas and the centred
     * width morph would otherwise cause.
     */
    readonly property real inputPadRight: bud.shown ? bud.budR + 2 * s : 0

    onHoveredChanged: {
        if (hovered) {
            hoverLatch = true;
            graceTimer.stop();
            graceRetries = 0;
        } else {
            graceRetries = 0;
            graceTimer.restart();
        }
    }

    /**
     * The grace timer waits for the morph to settle before collapsing. A pill
     * whose target geometry keeps moving (a workspace appearing, a tray icon
     * arriving) never reaches the threshold and would stay expanded forever.
     * Give the settle a bounded number of chances, then collapse regardless.
     */
    property int graceRetries: 0

    Timer {
        id: graceTimer
        interval: 300
        onTriggered: {
            if (pill.morphCloseness < 0.95 && pill.graceRetries < 6) {
                pill.graceRetries++;
                graceTimer.restart();
                return;
            }
            pill.graceRetries = 0;
            pill.hoverLatch = false;
        }
    }

    /**
     * Tap-to-pin only matters for the transient hover pill; in bar mode the
     * row is already permanent and a pin would only grab the whole screen's
     * input on a stray click.
     */
    TapHandler {
        enabled: !pill.surfaceOpen && !pill.barMode
        gesturePolicy: TapHandler.WithinBounds
        onTapped: pill.pinned = !pill.pinned
    }

    /**
     * Game-mode face: the pill docks into a flush top bar carrying only the clock
     * and, when something plays, the current track. Everything else the desktop
     * usually shows is deliberately gone.
     */
    Item {
        id: gameBar
        anchors.fill: parent
        enabled: pill.mode === "game"
        opacity: pill.mode === "game" ? Math.pow(pill.morphCloseness, 1.2) : 0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 18 * pill.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9 * pill.s
            opacity: pill.hasMedia ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * pill.s
                height: 26 * pill.s
                radius: 7 * pill.s
                color: PillTheme.tileBg
                clip: true
                Image {
                    id: pillTrackArt
                    anchors.fill: parent
                    source: MprisController.activePlayer?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    // Cover art arrives at whatever resolution the player ships
                    // (commonly 1000x1000+, i.e. ~4 MB decoded) and this tile is
                    // 26px. Decode at 2x the drawn size instead of native.
                    sourceSize.width: Math.max(1, Math.round(pillTrackArt.width * 2))
                    sourceSize.height: Math.max(1, Math.round(pillTrackArt.height * 2))
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: MprisController.activePlayer?.trackTitle ?? ""
                    color: PillTheme.cream
                    font.family: PillTheme.font
                    font.pixelSize: 12.5 * pill.s
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220 * pill.s)
                }
                Text {
                    text: PillTheme.joinArtists(MprisController.activePlayer?.trackArtists,
                                                MprisController.activePlayer?.trackArtist)
                    color: PillTheme.dim
                    font.family: PillTheme.font
                    font.pixelSize: 10.5 * pill.s
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220 * pill.s)
                    visible: text.length > 0
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: clock.hhmm
            color: PillTheme.cream
            font.family: PillTheme.font
            font.pixelSize: 16 * pill.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
    }

    Item {
        id: rest
        anchors.fill: parent
        opacity: (pill.expanded || pill.mode === "game" || pill.mode === "toast" || pill.mode === "osd") ? 0 : Math.pow(pill.morphCloseness, 1.5)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: pill.mode === "rest" ? PillMotion.fast : Math.round(260 * PillMotion.mult) } }

        Row {
            id: restRow
            anchors.centerIn: parent
            spacing: 9 * pill.s

            Item {
                id: restKanji
                anchors.verticalCenter: parent.verticalCenter
                width: kanjiFill.implicitWidth
                height: kanjiFill.implicitHeight

                Text {
                    anchors.fill: parent
                    opacity: PillTheme.showGlyphs ? 1 : 0
                    text: kanjiFill.text
                    color: "transparent"
                    font: kanjiFill.font
                    style: Text.Outline
                    styleColor: Qt.alpha(PillTheme.vermLit,
                        Math.min(1, (pill.mode === "rest" || !pill.hoverSoulGate ? 0.5 : 0) + pill.kanjiFlash))
                    Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }
                }

                Text {
                    id: kanjiFill
                    opacity: PillTheme.showGlyphs ? 1 : 0
                    text: PillTheme.glyph("clock")
                    color: PillTheme.cream
                    font.family: PillTheme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 15 * pill.s
                    Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }
                }

                GlyphIcon {
                    anchors.centerIn: parent
                    opacity: PillTheme.showGlyphs ? 0 : 1
                    width: pill.iconPx
                    height: pill.iconPx
                    name: "clock"
                    color: PillTheme.cream
                    stroke: 1.7
                    Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }
                }

            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clock.hhmm
                color: PillTheme.cream
                font.family: PillTheme.font
                font.pixelSize: 16 * pill.s
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }
    }

    Item {
        id: hover
        anchors.fill: parent
        opacity: pill.mode === "hover" ? Math.pow(pill.morphCloseness, 1.2) : 0
        visible: true
        Behavior on opacity { NumberAnimation { duration: pill.mode === "hover" ? PillMotion.fast : 40 } }

        readonly property bool live: pill.mode === "hover"

        Row {
            id: hoverRow
            // Whole-pixel centring: fractional text widths in the row would land
            // every glyph on a half pixel and smear the strokes.
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            spacing: Math.round((Config.options?.bar?.pill?.rowSpacing ?? 20) * pill.s)

            PillWorkspaces {
                id: ws
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                visible: pill.hoverModules?.workspaces ?? true
                screenName: pill.screenName
                s: pill.s
                gap: 8 * pill.s
                enabled: hover.live
                onHoverIndexChanged: if (hoverIndex >= 0) {
                    pill.soulTarget = "ws";
                    pill.soulWsIndex = hoverIndex;
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                visible: ws.visible
                color: PillTheme.hair
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(hoverClock.implicitWidth)
                height: Math.ceil(hoverClock.implicitHeight)

                Column {
                    id: hoverClock
                    anchors.centerIn: parent
                    spacing: 2 * pill.s
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.hhmm
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 18 * pill.s
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.date
                        color: PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 8.5 * pill.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.6 * pill.s
                    }
                }

                MouseArea {
                    anchors.centerIn: parent
                    width: hoverClock.implicitWidth + 22 * pill.s
                    height: hoverClock.implicitHeight + 10 * pill.s
                    enabled: hover.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("calendar")
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                visible: statusRow.visibleChildren.length > 0
                color: PillTheme.hair
            }

            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round((Config.options?.bar?.pill?.iconSpacing ?? 12) * pill.s)

                Row {
                    id: weatherGlance
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (pill.hoverModules?.weather ?? true) && PillWeather.ready
                    spacing: 5 * pill.s

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        enabled: hover.live
                    }
                    TapHandler {
                        enabled: hover.live
                        onTapped: pill.requestSurface("calendar")
                    }

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16 * pill.s
                        height: 16 * pill.s
                        name: PillWeather.glyphFor(PillWeather.codeNow, PillWeather.isDay)
                        color: PillTheme.subtle
                        stroke: 1.8
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PillWeather.tempNow + "°"
                        color: PillTheme.subtle
                        font.family: PillTheme.font
                        font.pixelSize: 12.5 * pill.s
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }
                }

                Tray {
                    id: trayRowItem
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModules?.tray ?? true
                    s: pill.s
                    barWindow: pill.barWindow
                    enabled: hover.live
                    menuOpen: pill.trayMenuOpen
                    onMenuRequested: (item, anchorX) => pill.trayMenuRequested(item, anchorX)
                }

                Item {
                    id: wifiIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (pill.hoverModules?.wifi ?? true) && Network.wifiEnabled
                    width: pill.iconPx
                    height: pill.iconPx

                    WifiGlyph {
                        anchors.centerIn: parent
                        s: pill.s
                        level: Network.networkStrength / 100
                        on: Network.wifiEnabled
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pill.linkInitialView = "wifi";
                            pill.requestSurface("link");
                        }
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "wifi"
                    }
                }

                Item {
                    id: batteryIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (pill.hoverModules?.battery ?? true) && Battery.available
                    width: Math.ceil(battPct.implicitWidth)
                    height: pill.iconPx

                    Text {
                        id: battPct
                        anchors.centerIn: parent
                        text: Math.round(Battery.percentage * 100) + "%"
                        color: Battery.isLow ? PillTheme.vermLit
                            : (Battery.isCharging ? PillTheme.flameGlow : PillTheme.subtle)
                        font.family: PillTheme.font
                        font.pixelSize: 13 * pill.s
                        font.weight: Battery.isCharging ? Font.DemiBold : Font.Medium
                        font.features: ({ "tnum": 1 })
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("battery")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "battery"
                    }
                }

                Item {
                    id: inboxIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModules?.inbox ?? true
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "inbox"
                        color: inboxArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                        stroke: 1.7
                    }

                    Rectangle {
                        visible: Notifications.unread > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -2 * pill.s
                        anchors.rightMargin: -2 * pill.s
                        width: 5 * pill.s
                        height: 5 * pill.s
                        radius: width / 2
                        color: PillTheme.flameGlow
                    }

                    MouseArea {
                        id: inboxArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("link")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "inbox"
                    }
                }

                // Hairline between the status cluster (weather/tray/wifi/battery/
                // inbox) and the tool surfaces — the row reads as sections, not
                // one long run of icons.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 18 * pill.s
                    color: PillTheme.hair
                    visible: (weatherGlance.visible || trayRowItem.visible || wifiIcon.visible || batteryIcon.visible || inboxIcon.visible)
                        && (launcherIcon.visible || glanceIcon.visible || mixerIcon.visible || clipboardIcon.visible || recorderIcon.visible || sysmonIcon.visible)
                }

                Item {
                    id: launcherIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.launcherEnabled
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "app-window"
                        color: launcherArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: launcherArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("launcher")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "launcher"
                    }
                }

                Item {
                    id: glanceIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.glanceEnabled
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "agenda"
                        color: glanceArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: glanceArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("glance")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "glance"
                    }
                }

                Item {
                    id: mixerIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModules?.mixer ?? true
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "mixer"
                        color: mixerArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: mixerArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("mixer")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "mixer"
                    }
                }

                Item {
                    id: clipboardIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.clipboardEnabled
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "clipboard"
                        color: clipboardArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: clipboardArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("clipboard")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "clipboard"
                    }
                }

                Item {
                    id: recorderIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.recorderEnabled
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "record"
                        color: RecorderStatus.isRecording ? PillTheme.vermLit
                            : (recorderArea.containsMouse ? PillTheme.cream : PillTheme.iconDim)
                        stroke: 1.7
                    }

                    MouseArea {
                        id: recorderArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("recorder")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "recorder"
                    }
                }

                Item {
                    id: sysmonIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.sysmonEnabled
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "monitor"
                        color: sysmonArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: sysmonArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("sysmon")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "sysmon"
                    }
                }

                /**
                 * The pill replaces the bar, so it also has to be the way into the
                 * shell's own panels. These two reach iNiR's sidebars directly;
                 * everything else in this row belongs to the pill itself.
                 */
                // Hairline before the shell shortcuts (sidebars + power).
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 18 * pill.s
                    color: PillTheme.hair
                    visible: (launcherIcon.visible || glanceIcon.visible || mixerIcon.visible || clipboardIcon.visible || recorderIcon.visible || sysmonIcon.visible
                        || weatherGlance.visible || trayRowItem.visible || wifiIcon.visible || batteryIcon.visible || inboxIcon.visible)
                        && (sidebarLeftIcon.visible || sidebarRightIcon.visible || powerIcon.visible)
                }

                Item {
                    id: sidebarLeftIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModules?.sidebars ?? true
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "sparkles"
                        color: sidebarLeftArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: sidebarLeftArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            GlobalStates.toggleSidebarLeft(pill.screenName);
                            pill.pinned = false;
                        }
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "sidebarLeft"
                    }
                }

                Item {
                    id: sidebarRightIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModules?.sidebars ?? true
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "cog"
                        color: sidebarRightArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                        stroke: 1.6
                    }

                    MouseArea {
                        id: sidebarRightArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            GlobalStates.toggleSidebarRight(pill.screenName);
                            pill.pinned = false;
                        }
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "sidebarRight"
                    }
                }

                Item {
                    id: powerIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModules?.power ?? true
                    width: pill.iconPx
                    height: pill.iconPx

                    GlyphIcon {
                        anchors.fill: parent
                        name: "shutdown"
                        color: powerArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        anchors.margins: -8 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("power")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "power"
                    }
                }
            }
        }
    }

    /**
     * Volume, brightness, battery and workspace flashes. Always instantiated: it
     * owns the timers that detect those transitions and drives `osdActive`.
     */
    PillOsd {
        id: osd
        anchors.fill: parent
        anchors.topMargin: (pill.compactAnnounceMode ? 7 : 12) * pill.s
        anchors.leftMargin: (pill.compactAnnounceMode ? 12 : 18) * pill.s
        anchors.rightMargin: (pill.compactAnnounceMode ? 12 : 18) * pill.s
        anchors.bottomMargin: (pill.compactAnnounceMode ? 7 : 12) * pill.s
        s: pill.s
        compact: pill.compactAnnounceMode
        screenName: pill.screenName
        outputAllowed: pill.osdOutputEnabled
        suppressed: pill.surfaceOpen || pill.held
        expanded: pill.expanded
        enabled: pill.mode === "osd"
        opacity: pill.mode === "osd" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard }
        }
    }

    /**
     * Morphing surfaces, one latch-once Loader each (see surfaceItem). Eager, they
     * dominate startup and per-monitor RAM; a surface is built synchronously on its
     * first open and kept. Each loader fills the pill so the PillSurface inside
     * anchors exactly as it would as a direct child.
     */
    Loader {
        id: ldPower
        active: false
        anchors.fill: parent
        sourceComponent: PillPower {
            s: pill.s
            open: pill.surface === "power"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldMedia
        active: false
        anchors.fill: parent
        sourceComponent: PillMedia {
            s: pill.s
            open: pill.surface === "media"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldBattery
        active: false
        anchors.fill: parent
        sourceComponent: PillBatterySurface {
            s: pill.s
            open: pill.surface === "battery"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldCalendar
        active: false
        anchors.fill: parent
        sourceComponent: PillCalendar {
            s: pill.s
            open: pill.surface === "calendar"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldLink
        active: false
        anchors.fill: parent
        sourceComponent: PillLink {
            s: pill.s
            open: pill.surface === "link"
            initialView: pill.linkInitialView
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldMixer
        active: false
        anchors.fill: parent
        sourceComponent: PillMixer {
            s: pill.s
            open: pill.surface === "mixer"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldSysmon
        active: false
        anchors.fill: parent
        sourceComponent: PillSysmonSurface {
            s: pill.s
            open: pill.surface === "sysmon"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldClipboard
        active: false
        anchors.fill: parent
        sourceComponent: PillClipboard {
            s: pill.s
            open: pill.surface === "clipboard"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldGlance
        active: false
        anchors.fill: parent
        sourceComponent: PillGlance {
            s: pill.s
            open: pill.surface === "glance"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestJump: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldLauncher
        active: false
        anchors.fill: parent
        sourceComponent: PillLauncher {
            s: pill.s
            open: pill.surface === "launcher"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldRecorder
        active: false
        anchors.fill: parent
        sourceComponent: PillRecorder {
            s: pill.s
            open: pill.surface === "recorder"
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    /**
     * Toast face. Unlike the surfaces it has no PillSurface lifecycle: it rides the
     * rest pill, shows the newest popup, and yields the moment the pill is hovered
     * or pinned.
     */
    Loader {
        id: toastLoader
        active: pill.toastActive
        anchors.fill: parent
        anchors.topMargin: (pill.compactAnnounceMode ? 6 : 12) * pill.s
        anchors.leftMargin: (pill.compactAnnounceMode ? 8 : 16) * pill.s
        anchors.rightMargin: (pill.compactAnnounceMode ? 8 : 16) * pill.s
        anchors.bottomMargin: (pill.compactAnnounceMode ? 6 : 12) * pill.s
        enabled: pill.mode === "toast"
        opacity: pill.mode === "toast" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }

        sourceComponent: Toast {
            s: pill.s
            compact: pill.compactAnnounceMode
            live: pill.mode === "toast"
            notif: PillNotifs.popups[PillNotifs.popups.length - 1]
        }
    }
}
