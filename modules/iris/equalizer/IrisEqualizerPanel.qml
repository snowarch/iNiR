pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// iRiS Equalizer: the full EasyEffects output chain in one panel.
//
//  - Band EQ with the response curve drawn through the handles, over the
//    background spectrum (IrisEqBands).
//  - Whole-chain presets: save the current chain, load a saved one, plus the
//    factory chains (IrisEqPresets).
//  - Five modules, each with an instant on/off switch, simple controls
//    and factory presets (IrisEqModuleCard × 4, IrisEqCrystalizer × 1),
//    split into a "Colour" and a "Control" section.
//
// The drawn order matches IrisAudio.chainOrder — autogain before the limiter,
// because autogain normalises loudness and must run before the limiter closes
// the chain. That order lives in the service and governs what is written to
// the engine; this layout is presentation only.
//
// Not rendered here: the profile row (IrisEqProfiles), deliberately. It also
// carried the master chain bypass switch, so nothing in this panel writes
// IrisAudio.setGlobalBypass() any more. The component is still registered in
// qmldir and its file is intact, so restoring the row is a one-line change.
//
// Wiring the orchestrator owns (do NOT add here — it lives outside this
// directory): an OnDemandPanelLoader entry in ShellIrisPanelsImpl.qml with
// `component: IrisEqualizerPanel { open: GlobalStates.irisEqualizerOpen }`,
// the `irisEqualizerOpen` flag in GlobalStates.qml, and the open triggers
// (volume-widget click, keybind/IPC, Control Center entry). This panel only
// asks for `open` and emits `closeRequested`.
//
// Honest degradation: until IrisAudio.ready is true the panel shows a
// status card, never a broken EQ. ensureRunning() is called when the panel
// opens — a visible, lifecycle-appropriate place, never a hidden load.
PanelWindow {
    id: root

    property bool open: false
    signal closeRequested()

    // Presentation gate: the surface animates in once, already composed.
    // It opens the moment the engine answers; showAnyway is purely the
    // fallback so a dead or slow engine still opens honest loading
    // placeholders instead of hanging invisible. 800 ms bounds the worst
    // case (cold bridge spawn plus snapshot round-trip) without ever
    // delaying the common warm-engine open, which fires on `ready`.
    property bool showAnyway: false
    Timer {
        id: showTimer
        interval: 800
        onTriggered: root.showAnyway = true
    }
    onOpenChanged: {
        if (root.open) {
            root.showAnyway = false
            showTimer.restart()
            IrisAudio.ensureRunning()
            // ensureRunning() returns early once the socket is up, so a reopen
            // over a stale snapshot would otherwise trust yesterday's answer.
            IrisAudio.refresh()
            root.applyStored()
        } else {
            showTimer.stop()
            root.showAnyway = false
        }
    }

    // EasyEffects coming back is never announced to us: nothing re-asks the
    // bridge for status once the socket is connected, so the panel would sit on
    // "waiting for EasyEffects…" until the user pressed Try again. Polled only
    // while the engine is actually missing, so a healthy panel costs nothing.
    Timer {
        id: enginePollTimer
        interval: 1500
        repeat: true
        // Not `!engineReady` alone. Nothing sets `ready` back to false when the
        // engine dies, so a poll gated on it alone switches itself off the
        // moment it is needed and nothing ever asks again.
        running: root.open && (!root.engineReady || IrisAudio.lastError.length > 0)
        onTriggered: IrisAudio.refresh()
    }

    readonly property real d: IrisStyle.density
    readonly property bool engineReady: IrisAudio.ready
    onEngineReadyChanged: {
        showTimer.stop()
        root.applyStored()
    }

    // Settings › Equalizer, honoured on open. Only explicitly stored values
    // apply (an unset key means the user has not chosen), only what disagrees
    // with the engine is sent, and never mid-rebuild — so opening the panel is
    // a no-op for anyone who never touched the section.
    function applyStored(): void {
        if (!root.open || !IrisAudio.ready || IrisAudio.rebuilding || IrisAudio.pendingCount > 0) return
        IrisAudio.applyPreferences(Config.getNestedValue("iris.equalizer.enabled"),
            Config.getNestedValue("iris.equalizer.bands"))
    }

    // The surface stays unmapped until the presentation gate opens, so the frame
    // and the window arrive together exactly once. Studio and Sidebar can bind this
    // straight to root.open because their frame opens on the same beat; here the
    // frame waits for the engine, and mapping the surface early showed an empty
    // plate first and then animated the real panel on top of it. frame.progress
    // keeps it mapped through the close animation, after root.open is already false.
    visible: (root.open && (root.engineReady || root.showAnyway)) || frame.progress > 0
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.visible
    }
    screen: outputHold.output
    color: "transparent"
    // Full-screen window like IrisSidebar: the mask covers the dismiss
    // layer while open (frame only while closed/animating), so clicks
    // outside the frame reach the client instead of falling through a
    // 608 px strip. The frame's own catch-all below swallows inside
    // clicks first.
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:iris-equalizer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: (!root.open || !frame.armed) ? frame : dismissArea }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.closeRequested()
    }

    MouseArea {
        id: dismissArea
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // Geometry math: clamp the card between 380 and 880 wide, never taller than
    // the usable output.
    //
    // The upper clamp is 880 rather than 720 because the band field has to hold
    // a full page of ten columns AND the scroll margin IrisEqBands takes off
    // both sides. Narrower than that and the margin and the tenth column
    // compete for the same pixels, the margin wins, and the page cap drops
    // below ten - which splits a 10-band layout across two pages.
    //
    // The frame is anchored to the right edge (x: parent.width - width - 12),
    // so this grows leftwards. The 0.46 fraction keeps it at under half the
    // screen on anything narrower, and max(380, …) still protects small
    // screens.
    readonly property real safePadding: Math.max(12, Math.round(Math.min(screen?.width ?? 1920, screen?.height ?? 1080) * 0.02))
    readonly property real panelWidth: Math.round(Math.min(880, Math.max(380, (screen?.width ?? 1920) * 0.46)))
    readonly property real maxPanelHeight: Math.round(Math.min(920, (screen?.height ?? 1080) - root.safePadding * 2))

    IrisMorphSurface {
        id: frame
        objectName: "eqFrame"
        open: root.open && (root.engineReady || root.showAnyway)
        motionSurface: "settings"
        radius: IrisStyle.surfaceRadius("settings", IrisStyle.radiusPanel)
        light: IrisStyle.surfaceLight("settings", IrisStyle.wallpaperLight)
        x: parent.width - width - Math.round(12 * root.d)
        y: Math.round((parent.height - height) / 2)
        width: root.panelWidth
        height: Math.min(root.maxPanelHeight, Math.max(Math.round(480 * root.d), body.implicitHeight + Math.round(24 * root.d)))
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: body
            objectName: "eqBody"
            anchors.fill: parent
            anchors.margins: IrisStyle.concentricPad(frame.radius, 16 * root.d)
            spacing: Math.round(12 * root.d)

            // -- header --------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.d)
                IrisMark { implicitSize: Math.round(24 * root.d) }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        text: Translation.tr("Equalizer")
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: IrisStyle.typeTitle
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: root.headline
                        color: root.engineReady ? IrisStyle.muted : IrisStyle.secondaryAccent
                        font.pixelSize: IrisStyle.typeFootnote
                        elide: Text.ElideRight
                    }
                }
                IrisIconButton {
                    materialIcon: "refresh"
                    Accessible.name: Translation.tr("Ask the engine again")
                    onClicked: {
                        IrisAudio.ensureRunning()
                        IrisAudio.refresh()
                        IrisAudio.listPresets()
                    }
                }
                IrisIconButton {
                    materialIcon: "close"
                    Accessible.name: Translation.tr("Close equalizer")
                    onClicked: root.closeRequested()
                }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: sections.implicitHeight + Math.round(8 * root.d)
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: IrisScrollBar {}

          // Hold the scroll across content resizes.
          //
          // Choosing a preset or switching a module makes cards appear and
          // disappear, so sections.implicitHeight moves and takes this
          // contentHeight with it. A Flickable clamps contentY whenever the
          // range under the pointer shrinks, and nothing else holds contentY,
          // so without this the clamp is free to put the view somewhere the
          // user never asked for.
          //
          // lastY is where the user put the view. On a resize we put it back,
          // clamped to the new bounds - so a card collapsing above the cursor
          // no longer drags the view with it, and growing content leaves the
          // offset alone. The restoring guard matters: without it the
          // correction we write would be recorded as user intent on the way
          // out and ratchet the panel back to the top.
          property real lastY: 0
          property bool restoring: false
          onContentYChanged: {
              if (!flick.restoring) flick.lastY = flick.contentY
          }
          onContentHeightChanged: {
              if (flick.restoring || flick.lastY <= 0) return
              flick.restoring = true
              flick.contentY = Math.max(0, Math.min(flick.lastY, Math.max(0, flick.contentHeight - flick.height)))
              flick.restoring = false
          }

                ColumnLayout {
                    id: sections
                    width: flick.width
                    spacing: Math.round(16 * root.d)

                    // Engine errors only. Loading state lives in the headline
                    // (fixed position, always laid out); this card appears
                    // solely for failures, with details and a retry.
                    Rectangle {
                        Layout.fillWidth: true
                        visible: IrisAudio.lastError.length > 0
                        implicitHeight: statusCol.implicitHeight + Math.round(20 * root.d)
                        radius: IrisStyle.radiusCard
                        color: IrisStyle.tintFill(IrisStyle.secondaryAccent)
                        ColumnLayout {
                            id: statusCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Math.round(12 * root.d)
                            spacing: Math.round(6 * root.d)
                            RowLayout {
                                spacing: Math.round(8 * root.d)
                                MaterialSymbol {
                                    text: IrisAudio.lastError.length > 0 ? "error" : "hourglass_top"
                                    iconSize: Math.round(20 * root.d)
                                    color: IrisStyle.secondaryAccent
                                }
                                IrisText {
                                    Layout.fillWidth: true
                                    text: root.statusText
                                    color: IrisStyle.text
                                    font.pixelSize: IrisStyle.typeLabel
                                    font.weight: IrisStyle.weight(Font.DemiBold)
                                    wrapMode: Text.WordWrap
                                }
                            }
                            IrisText {
                                Layout.fillWidth: true
                                visible: IrisAudio.lastError.length > 0
                                text: IrisAudio.lastError
                                color: IrisStyle.muted
                                font.pixelSize: IrisStyle.typeFootnote
                                wrapMode: Text.WordWrap
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(8 * root.d)
                                IrisButton {
                                    visible: IrisAudio.lastError === "easyeffects_unavailable"
                                        && EasyEffects.available && !EasyEffects.active
                                    text: Translation.tr("Open EasyEffects")
                                    emphasized: true
                                    buttonRadius: height / 2
                                    onClicked: EasyEffects.enable()
                                }
                                IrisButton {
                                    visible: IrisAudio.lastError === "easyeffects_unavailable"
                                        && EasyEffects.available && EasyEffects.active && !root.engineReady
                                    enabled: false
                                    text: Translation.tr("Starting EasyEffects…")
                                    buttonRadius: height / 2
                                }
                                IrisButton {
                                    text: Translation.tr("Try again")
                                    buttonRadius: height / 2
                                    onClicked: {
                                        IrisAudio.ensureRunning()
                                        IrisAudio.refresh()
                                    }
                                }
                            }
                        }
                    }

                    IrisEqPresets {
                        Layout.fillWidth: true
                        engineReady: root.engineReady
                    }

                    IrisEqBands {
                        Layout.fillWidth: true
                        engineReady: root.engineReady
                    }

                    SectionTitle { title: Translation.tr("Colour"); tint: IrisStyle.secondaryAccent }
                    IrisEqModuleCard {
                        Layout.fillWidth: true
                        moduleId: "bass_enhancer"
                        engineReady: root.engineReady
                    }
                    IrisEqCrystalizer {
                        Layout.fillWidth: true
                        engineReady: root.engineReady
                    }
                    IrisEqModuleCard {
                        Layout.fillWidth: true
                        moduleId: "exciter"
                        engineReady: root.engineReady
                    }

                    SectionTitle { title: Translation.tr("Control"); tint: IrisStyle.identity.teal }
                    // Autogain before limiter, matching the engine's chain order
                    // (IrisAudio.chainOrder). The limiter is last in the DSP
                    // chain, so it is last here too.
                    IrisEqModuleCard {
                        Layout.fillWidth: true
                        moduleId: "autogain"
                        engineReady: root.engineReady
                    }
                    IrisEqModuleCard {
                        Layout.fillWidth: true
                        moduleId: "limiter"
                        engineReady: root.engineReady
                    }

                    IrisText {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Math.round(4 * root.d)
                        text: Translation.tr("Switches flip bypass instantly — the sound never reloads. Only the band count and chain presets rebuild the chain.")
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeFootnote
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    readonly property string headline: {
        if (IrisAudio.lastError.length > 0) return Translation.tr("The audio engine needs attention")
        if (!IrisAudio.available) return Translation.tr("Starting the audio bridge…")
        if (!root.engineReady) return Translation.tr("Waiting for EasyEffects…")
        const name = String(IrisAudio.presetName ?? "")
        const live = Object.keys(IrisAudio.modules ?? {}).filter(id => (IrisAudio.modules[id] ?? {}).active).length
        return name.length > 0 ? Translation.tr("%1 · %2 shaping").arg(name).arg(live === 1 ? Translation.tr("1 module") : Translation.tr("%1 modules").arg(live))
            : Translation.tr("Flat chain · nothing shaping yet")
    }

    readonly property string statusText: {
        if (IrisAudio.lastError.length > 0) return Translation.tr("EasyEffects is not answering yet")
        if (!IrisAudio.available) return Translation.tr("Starting the audio bridge…")
        return Translation.tr("Waiting for EasyEffects…")
    }

    // Section eyebrows carry one accent each: where you are in the chain.
    component SectionTitle: RowLayout {
        property string title: ""
        property color tint: IrisStyle.accent
        spacing: Math.round(8 * IrisStyle.density)
        Rectangle {
            implicitWidth: IrisStyle.accentRuleWidth
            implicitHeight: IrisStyle.accentRuleHeight
            radius: height / 2
            color: tint
        }
        IrisText {
            text: title
            role: IrisText.Eyebrow
            color: tint
        }
    }
}
