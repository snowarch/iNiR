pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.iris.style
import qs.modules.iris.components

// A run of wallpapers moved by one number: `pos`, the place in the list that sits in front. A layout only says where
// the wallpaper `d` places away goes (`place(d)`: centre x/y, scale of the card, opacity, depth); between two places
// a card is the blend of both, so every move, drag or fling is one spring on `pos` and the cards ride it by transform.
// Only `pool` cards exist, handed new wallpapers out of sight as the run goes by (SekaiPop's wheel): a folder of 500
// costs what one of nine does.
Item {
    id: root

    required property var engine
    property int pool: 9
    // Where the pool sits around `pos`: a run that shows more ahead than behind leans forward.
    property real lead: 0
    property real cardWidth: 480
    property real cardHeight: 300
    property real cardRadius: IrisStyle.radiusCard
    property var place: function(d) { return { x: d * root.cardWidth, y: 0, s: 1, o: 1, z: 0 } }
    // Pixels of drag that turn one wallpaper.
    property real dragPitch: root.cardWidth * 0.6
    property bool interactive: true
    // How much each place away steps back into the body (a fan dims its far cards, a mosaic barely).
    property real recede: 0.3
    property real recedeMost: 0.55

    readonly property real pos: root.dragging ? root.dragPos : spring.value
    readonly property bool rested: !spring.running && !root.dragging && root.restedFor
    readonly property int count: root.engine.count

    signal activated(int index)

    IrisSpring {
        id: spring
        surface: "gallery"
        intent: "move"
        to: root.engine.selectedIndex
        animate: IrisStyle.motionEnabled
    }

    // A new list is dealt: the run spins in from behind its start.
    property int dealt: -1
    readonly property int generation: root.engine.listGeneration
    onGenerationChanged: root.deal()
    function deal(): void {
        if (root.dealt === root.generation) return
        root.dealt = root.generation
        if (!IrisStyle.motionEnabled || root.count === 0) { spring.jump(); return }
        spring.animate = false
        spring.to = root.engine.selectedIndex - 1.8
        spring.animate = true
        spring.to = Qt.binding(() => root.engine.selectedIndex)
    }

    // The list moved under the wallpaper in front: the run moves with it instead of turning to it.
    Connections {
        target: root.engine
        function onShifted(delta: int): void {
            const at = spring.value + delta
            spring.animate = false
            spring.to = at
            spring.animate = IrisStyle.motionEnabled
            spring.to = Qt.binding(() => root.engine.selectedIndex)
        }
    }

    // A beat after it stops, so pictures going past don't each load their sharp copy.
    property bool restedFor: true
    Timer { id: rest; interval: 140; onTriggered: root.restedFor = true }
    onPosChanged: { root.restedFor = false; rest.restart() }

    property bool dragging: false
    property real dragPos: 0
    DragHandler {
        id: drag
        enabled: root.interactive && root.count > 1
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        property real from: 0
        property real lastT: 0
        property real lastX: 0
        property real velocity: 0
        onActiveChanged: {
            if (drag.active) {
                drag.from = spring.value
                root.dragPos = spring.value
                drag.lastT = Date.now()
                drag.lastX = 0
                drag.velocity = 0
                root.dragging = true
                return
            }
            // Let go: it carries on with the speed it had, then rests on a wallpaper.
            const lead = Math.max(-3, Math.min(3, drag.velocity * 0.28))
            const target = Math.max(0, Math.min(root.count - 1, Math.round(root.dragPos + lead)))
            spring.animate = false
            spring.to = root.dragPos
            spring.animate = IrisStyle.motionEnabled
            spring.velocity = drag.velocity
            root.dragging = false
            root.engine.select(target)
            spring.to = Qt.binding(() => root.engine.selectedIndex)
        }
        onTranslationChanged: {
            if (!drag.active) return
            const now = Date.now()
            const dx = drag.translation.x
            root.dragPos = Math.max(-0.4, Math.min(root.count - 0.6, drag.from - dx / root.dragPitch))
            const dt = Math.max(1, now - drag.lastT)
            drag.velocity = drag.velocity * 0.6 + (-(dx - drag.lastX) / root.dragPitch / dt * 1000) * 0.4
            drag.lastT = now
            drag.lastX = dx
        }
    }
    // One notch, one wallpaper; a trackpad adds up to the same.
    WheelHandler {
        enabled: root.interactive
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real gathered: 0
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (delta === 0) return
            gathered += delta
            const steps = Math.trunc(gathered / 120)
            if (steps !== 0) {
                root.engine.move(-steps)
                gathered -= steps * 120
            }
        }
    }

    function blend(d: real): var {
        const a = Math.floor(d)
        const t = d - a
        const p = root.place(a)
        if (t < 0.0001) return p
        const q = root.place(a + 1)
        return { x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t, s: p.s + (q.s - p.s) * t,
            o: p.o + (q.o - p.o) * t, z: p.z + (q.z - p.z) * t }
    }

    Repeater {
        model: root.pool
        delegate: Item {
            id: slot
            required property int index
            // Slot k always holds the places k, k ± pool...: whichever is nearest the window, so a card crossing the
            // screen never changes wallpaper; it is handed a new one only at the far edge.
            readonly property int logical: slot.index + root.pool * Math.round((root.pos + root.lead - slot.index) / root.pool)
            readonly property real d: slot.logical - root.pos
            readonly property bool valid: slot.logical >= 0 && slot.logical < root.count
            readonly property var entry: slot.valid ? root.engine.entryAt(slot.logical) : null
            readonly property var at: root.blend(slot.d)
            readonly property real near: Math.abs(slot.d)
            readonly property bool front: slot.near < 0.5
            readonly property bool hot: tap.hovered && root.rested

            // Sharp once the run rests on it, kept while it stays close, so a small turn doesn't drop it back.
            property bool sharp: false
            readonly property bool wantsSharp: root.rested && slot.near < 1.2 && slot.valid
            onWantsSharpChanged: if (slot.wantsSharp) slot.sharp = true
            onNearChanged: if (slot.near > 2.2) slot.sharp = false
            readonly property string key: String(slot.entry?.key ?? "")
            onKeyChanged: { slot.sharp = slot.wantsSharp; slot.full = false }
            // The original file of a web still waits for a longer look.
            property bool full: false
            Timer { id: fullDwell; interval: 900; running: slot.front && root.rested && root.engine.opened; onTriggered: slot.full = true }
            onFrontChanged: if (!slot.front) slot.full = false

            visible: slot.valid && slot.at.o > 0.01
            width: root.cardWidth
            height: root.cardHeight
            x: slot.at.x - width / 2
            y: slot.at.y - height / 2
            z: slot.at.z
            opacity: slot.at.o
            // The run sets the size frame by frame; only touch eases (eased together, a fast run never caught up
            // and the cards crossed the front small).
            property real touch: press.pressed ? IrisStyle.pressScale(0.97) : slot.hot && !slot.front ? 1.025 : 1
            Behavior on touch { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            scale: slot.at.s * slot.touch

            RectangularShadow {
                anchors.fill: card
                visible: slot.near < 1
                opacity: (1 - slot.near) * 0.55
                radius: card.radius
                blur: 36 * IrisStyle.density
                spread: -4 * IrisStyle.density
                offset: Qt.vector2d(0, 14 * IrisStyle.density)
                color: IrisStyle.shadow
            }
            WallpaperCard {
                id: card
                anchors.fill: parent
                engine: root.engine
                entry: slot.entry
                radius: root.cardRadius
                sharp: slot.sharp && root.engine.warm
                full: slot.full
                playing: slot.front && root.rested && root.engine.opened && root.engine.playMotion
                markScale: 1 / Math.max(0.35, slot.at.s)
            }
            // The ones further away step back into the body.
            Rectangle {
                anchors.fill: card
                radius: card.radius
                color: IrisStyle.surface
                property real lit: slot.hot ? 0.4 : 1
                Behavior on lit { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                opacity: Math.min(root.recedeMost, slot.near * root.recede) * lit
            }
            HoverHandler {
                id: tap
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: press
                onTapped: {
                    if (slot.front) root.activated(slot.logical)
                    else root.engine.select(slot.logical)
                }
                onDoubleTapped: root.engine.apply(slot.entry)
            }
        }
    }
}
