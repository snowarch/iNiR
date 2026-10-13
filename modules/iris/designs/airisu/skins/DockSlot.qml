import QtQuick
import "../components"

// AIRISU's dock slot: each app answers as a quiet key (AKey). The pointer lays a coat behind its icon at 45°, a press
// deepens it and carries the icon a hair (the host moves the icon by `shift`), the keyboard flags the coat's corner,
// and a launch paints the accent's lacquer across the slot once and lets it dry off, where iRiS hops. The engine keeps
// the click, the drag, the menus and the windows; this draws only how it answers.
Item {
    id: root
    property Item host
    readonly property bool hovered: root.host?.hovered ?? root.host?.containsMouse ?? false
    readonly property bool pressed: root.host?.down ?? root.host?.pressed ?? false
    readonly property var slot: root.host?.skinData ?? ({})
    // The icon's own box in the host, so the coat stands round the icon and not the whole slot.
    readonly property rect box: root.slot.box ?? Qt.rect(0, 0, root.width, root.height)
    readonly property int launches: root.slot.launches ?? 0
    readonly property int pad: Math.round(4 * Airisu.d)
    readonly property int shift: key.shift

    onLaunchesChanged: if (root.launches > 0 && Airisu.moving) launch.restart()

    AKey {
        id: key
        x: Math.round(root.box.x) - root.pad
        y: Math.round(root.box.y) - root.pad
        width: Math.round(root.box.width) + 2 * root.pad
        height: Math.round(root.box.height) + 2 * root.pad
        lacquer: "transparent"
        hovered: root.hovered
        pressed: root.pressed
        keyed: root.host?.visualFocus ?? false
    }
    ALacquer {
        id: inked
        x: key.x
        y: key.y
        width: key.width
        height: key.height
        cut: key.cut
        lacquer: "transparent"
        coat: Airisu.seal
        share: 0
        travel: 0
        opacity: 0
    }
    SequentialAnimation {
        id: launch
        ScriptAction { script: { inked.opacity = 1; inked.share = 0 } }
        NumberAnimation { target: inked; property: "share"; to: 1; duration: Airisu.tear; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
        NumberAnimation { target: inked; property: "opacity"; to: 0; duration: Airisu.ceremony; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
    }
}
