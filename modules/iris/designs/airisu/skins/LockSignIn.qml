pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's sign-in: the photo cut by the Design's die (without a picture, a die of the media's scrim with the initial),
// the name with the login over it, and one row of keys. The field is a slot sunk into the plate; each
// character typed lays one stripe in it, leaning at the die's 45° the way a livery's stripes do, and never the
// character itself; a selection lays them in the accent, and keyboard focus is the flag in the slot's uncut corner. At
// the end waits the unlock key, the accent's lacquer once there is something to send: while the lock checks a coat runs
// across it at 45° again and again, and a refusal shakes the card once from side to side. The field's label turns into
// the hint while there is one (Unlocking…, Incorrect password), so the card never holds an empty line. The engine keeps
// its TextInput over the slot (`fieldX`…), so focus, keys, the lock keyboard and PAM stay iRiS's; the card sits on the
// engine's plate (`plated`), so Lock › Plates still decides what it is made of.
Item {
    id: root
    property var host
    readonly property bool plated: true
    readonly property real d: root.host?.unit ?? Airisu.d
    readonly property real textScale: root.host?.textScale ?? 1
    function t(px: real): int { return Math.round(px * root.textScale) }
    function u(n: real): int { return Math.round(n * 4 * root.d) }
    readonly property var entry: root.host?.entry ?? ({})
    readonly property bool showPhoto: Boolean(root.entry?.avatar ?? true)
    readonly property bool showName: Boolean(root.entry?.name ?? true)
    readonly property bool showHint: Boolean(root.entry?.hint ?? true)
    readonly property bool editing: root.host?.editing ?? false
    readonly property bool working: root.host?.context?.unlockInProgress ?? false
    readonly property bool refused: root.host?.context?.showFailure ?? false
    readonly property bool fingerprints: root.host?.context?.fingerprintsConfigured ?? false
    readonly property bool focused: root.host?.focused ?? false
    readonly property int typed: root.host?.typed ?? 0
    readonly property int cursor: root.host?.cursor ?? root.typed
    readonly property int selectionStart: root.host?.selectionStart ?? 0
    readonly property int selectionEnd: root.host?.selectionEnd ?? 0
    readonly property int renderType: root.host?.renderType ?? Text.NativeRendering
    readonly property string displayName: root.host?.displayName ?? ""
    readonly property string userName: root.host?.userName ?? ""
    readonly property string initial: (root.displayName || root.userName || "?").charAt(0).toUpperCase()
    readonly property bool moving: Airisu.moving && !(root.host?.still ?? false)

    readonly property int pad: root.u(4)
    readonly property int photoWidth: root.u(18)
    readonly property int photoHeight: root.u(24)
    readonly property int keySize: root.u(10)
    readonly property int gap: root.u(1.5)
    // A stripe and the step to the next: the slot shows as many as fit and runs on under the caret.
    readonly property int stripe: root.u(1)
    readonly property int pitch: root.u(2.5)
    // A stripe's height, and so how far it leans over it.
    readonly property int lean: Math.round(root.keySize * 0.42)
    // Field width is the whole row, as iRiS's capsule is: the keyboard key, the slot and the unlock key.
    readonly property int rowWidth: Math.round(Math.max(160, Number(root.entry?.width ?? 248)) * root.d)
    readonly property int slotWidth: Math.max(root.u(16), root.rowWidth - 2 * root.keySize - 2 * root.gap)
    readonly property int columnX: root.pad + (root.showPhoto ? root.photoWidth + root.u(4) : 0)
    readonly property int columnWidth: root.keySize + root.gap + root.slotWidth + root.gap + root.keySize

    // Where the engine's TextInput lies: over the slot.
    readonly property real fieldX: root.columnX + root.keySize + root.gap
    readonly property real fieldY: words.y + fieldRow.y
    readonly property real fieldWidth: root.slotWidth
    readonly property real fieldHeight: root.keySize

    implicitWidth: root.columnX + root.columnWidth + root.pad
    implicitHeight: root.pad + Math.max(root.showPhoto ? root.photoHeight : 0, words.height) + root.pad

    // A refusal: the card is shaken once, side to side, the way a lock that will not turn answers the hand.
    Connections {
        // Only a context that can fail: a stand-in (the Design proof) is a plain model.
        target: typeof root.host?.context?.failed === "function" ? root.host.context : null
        function onFailed(): void { if (root.moving) shake.restart() }
    }
    property real sway: 0
    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "sway"; to: -root.u(2.5); duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "sway"; to: root.u(2); duration: 80; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "sway"; to: -root.u(1); duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "sway"; to: 0; duration: 60; easing.type: Easing.OutQuad }
    }

    Item {
        id: card
        width: root.width
        height: root.height
        transform: Translate { x: root.sway }

        // The photo, cut by the die.
        Item {
            id: photo
            visible: root.showPhoto
            x: root.pad
            y: root.pad
            width: root.photoWidth
            height: root.photoHeight
            property int sourceIndex: 0
            readonly property bool ready: picture.status === Image.Ready
            IrisImage {
                id: picture
                anchors.fill: parent
                source: photo.visible ? Directories.avatarSourceAt(photo.sourceIndex) : ""
                onStatusChanged: {
                    if (picture.status === Image.Error && photo.sourceIndex + 1 < Directories.userAvatarPaths.length)
                        Qt.callLater(() => photo.sourceIndex++)
                }
            }
            ShaderEffectSource {
                id: likeness
                visible: false
                width: photo.width
                height: photo.height
                sourceItem: photo.ready ? picture : null
                hideSource: true
            }
            ALacquer {
                anchors.fill: parent
                cut: Airisu.cutFor(photo.height)
                lacquer: photo.ready ? "transparent" : IrisStyle.mediaScrim
                texture: photo.ready ? likeness : null
                glaze: 0
            }
            AText {
                anchors.centerIn: parent
                visible: !photo.ready
                voice: "figure"
                size: root.t(IrisStyle.typeDisplay)
                renderType: root.renderType
                color: IrisStyle.onMediaSecondary
                text: root.initial
            }
        }

        Column {
            id: words
            x: root.columnX
            y: root.pad
            width: root.columnWidth
            spacing: 0

            // The login over the name, when the name is not the login itself.
            AText {
                width: parent.width
                visible: root.showName && root.userName.length > 0 && root.userName !== root.displayName
                voice: "ruby"
                size: root.t(IrisStyle.typeMeta)
                renderType: root.renderType
                color: IrisStyle.onMediaSecondary
                text: root.userName
            }
            AText {
                width: parent.width
                visible: root.showName
                size: root.t(IrisStyle.typeTitle)
                font.weight: Font.Bold
                renderType: root.renderType
                color: IrisStyle.onMedia
                text: root.displayName
            }
            Item { width: 1; height: root.showName ? root.u(3) : 0 }

            // What the field takes; the hint takes its place while there is one.
            AText {
                x: root.keySize + root.gap
                width: root.slotWidth
                voice: "ruby"
                size: root.t(IrisStyle.typeMeta)
                font.weight: root.showHint && (root.refused || root.working) ? Font.Bold : Font.Medium
                renderType: root.renderType
                color: root.showHint && root.refused ? IrisStyle.dangerOnMedia
                    : root.showHint && root.working ? IrisStyle.onMedia : IrisStyle.onMediaSecondary
                text: root.showHint && (root.refused || root.working) ? (root.host?.hint ?? "")
                    : root.fingerprints ? Translation.tr("Password or fingerprint") : Translation.tr("Password")
            }
            Item { width: 1; height: root.u(1.5) }

            Item {
                id: fieldRow
                width: parent.width
                height: root.keySize

                // The key that brings the lock keyboard.
                AKey {
                    id: keyboardKey
                    readonly property bool lit: root.host?.oskVisible ?? false
                    width: root.keySize
                    height: root.keySize
                    lacquer: keyboardKey.lit ? Airisu.sealOnMedia : IrisStyle.mediaScrim
                    coat: keyboardKey.lit ? Airisu.step(Airisu.sealOnMedia, keyboardArea.pressed ? Airisu.pressStep : Airisu.hoverStep)
                        : keyboardArea.pressed ? IrisStyle.onMediaFillHover : IrisStyle.onMediaFill
                    hovered: keyboardArea.containsMouse
                    pressed: keyboardArea.pressed
                    available: !root.editing
                    MaterialSymbol {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: keyboardKey.shift
                        anchors.verticalCenterOffset: keyboardKey.shift
                        text: "keyboard"
                        iconSize: Math.round(18 * root.d)
                        color: keyboardKey.lit ? IrisStyle.onTintFor(Airisu.sealOnMedia) : IrisStyle.onMedia
                    }
                    MouseArea {
                        id: keyboardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.editing
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: Translation.tr("Virtual keyboard")
                        onClicked: root.host?.toggleKeyboard()
                    }
                }

                // The slot.
                Item {
                    id: slot
                    readonly property int fits: Math.max(1, Math.floor((slot.width - 2 * root.u(2) - root.lean) / root.pitch))
                    // The stripes run on under the caret, as a field scrolls: the one being written is always in view.
                    readonly property int first: Math.max(0, Math.max(root.typed, root.cursor) + 1 - slot.fits)
                    readonly property int inset: root.u(2)
                    x: root.keySize + root.gap
                    width: root.slotWidth
                    height: root.keySize

                    AKey {
                        anchors.fill: parent
                        lacquer: IrisStyle.mediaScrim
                        keyed: root.focused
                        flag: Airisu.sealOnMedia
                        available: false
                    }
                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: slot.inset
                        anchors.rightMargin: slot.inset
                        clip: true
                        Repeater {
                            model: Math.max(0, Math.min(root.typed - slot.first, slot.fits))
                            Shape {
                                id: mark
                                required property int index
                                readonly property int at: slot.first + mark.index
                                readonly property bool chosen: mark.at >= root.selectionStart && mark.at < root.selectionEnd
                                x: mark.index * root.pitch
                                y: Math.round((slot.height - root.lean) / 2)
                                width: root.stripe + root.lean
                                height: root.lean
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    fillColor: mark.chosen ? Airisu.sealOnMedia : IrisStyle.onMedia
                                    strokeColor: "transparent"
                                    strokeWidth: 0
                                    // Leaning forward at the die's 45° over its own height.
                                    PathPolyline {
                                        path: [Qt.point(root.lean, 0), Qt.point(mark.width, 0), Qt.point(root.stripe, root.lean),
                                            Qt.point(0, root.lean), Qt.point(root.lean, 0)]
                                    }
                                }
                            }
                        }
                        // The caret, after the last stripe.
                        Rectangle {
                            id: caret
                            property bool blink: true
                            visible: root.focused && root.selectionStart === root.selectionEnd && caret.blink
                            x: Math.max(0, Math.min(parent.width - width, (root.cursor - slot.first) * root.pitch + Math.round(root.lean / 2)))
                            anchors.verticalCenter: parent.verticalCenter
                            width: Airisu.strong
                            height: Math.round(root.keySize * 0.5)
                            color: Airisu.sealOnMedia
                            Timer {
                                interval: 530
                                repeat: true
                                // A stand-in host (the Design proof) holds it lit.
                                running: root.focused && root.moving
                                onRunningChanged: caret.blink = true
                                onTriggered: caret.blink = !caret.blink
                            }
                            Connections {
                                target: root
                                function onTypedChanged(): void { caret.blink = true }
                                function onCursorChanged(): void { caret.blink = true }
                            }
                        }
                    }
                }

                // The unlock key.
                AKey {
                    id: unlockKey
                    readonly property bool ready: root.typed > 0 && !root.working
                    anchors.right: parent.right
                    width: root.keySize
                    height: root.keySize
                    lacquer: root.typed > 0 || root.working ? Airisu.sealOnMedia : IrisStyle.mediaScrim
                    coat: root.typed > 0 || root.working
                        ? Airisu.step(Airisu.sealOnMedia, unlockArea.pressed ? Airisu.pressStep : Airisu.hoverStep)
                        : IrisStyle.onMediaFill
                    hovered: unlockArea.containsMouse
                    pressed: unlockArea.pressed
                    available: unlockKey.ready && !root.editing
                    // While the lock checks, the key is repainted across at 45° again and again, a step deeper and back.
                    ALacquer {
                        id: checking
                        property bool deep: false
                        anchors.fill: parent
                        visible: root.working
                        cut: unlockKey.cut
                        lacquer: checking.deep ? Airisu.step(Airisu.sealOnMedia, Airisu.pressStep) : Airisu.sealOnMedia
                        Timer {
                            interval: Airisu.tear + Airisu.snap
                            repeat: true
                            running: root.working && root.moving
                            onRunningChanged: if (!running) checking.deep = false
                            onTriggered: checking.deep = !checking.deep
                        }
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: unlockKey.shift
                        anchors.verticalCenterOffset: unlockKey.shift
                        text: "arrow_forward"
                        iconSize: Math.round(20 * root.d)
                        color: root.typed > 0 || root.working ? IrisStyle.onTintFor(Airisu.sealOnMedia) : IrisStyle.onMediaTertiary
                    }
                    MouseArea {
                        id: unlockArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.editing
                        cursorShape: unlockKey.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: Translation.tr("Unlock")
                        onClicked: if (unlockKey.ready) root.host?.submit()
                    }
                }
            }
        }
    }
}
