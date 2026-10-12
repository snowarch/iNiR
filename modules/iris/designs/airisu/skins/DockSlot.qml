import QtQuick
import "../components"

// AIRISU's dock slot (SYSTEM.md law 6): each app is a sticker on the backing sheet, and the dock treats it like the
// press does. The pointer brings the crop marks round the sticker, never a plate under it and never a lift; a press runs
// the sticker out of register, never a shrink; and a launch prints it twice, two detents out of register and back,
// where iRiS hops. The engine keeps the click, the drag, the menus and the windows; this draws only how it answers.
Item {
    id: root
    property Item host
    readonly property bool hovered: root.host?.hovered ?? root.host?.containsMouse ?? false
    readonly property bool pressed: root.host?.down ?? root.host?.pressed ?? false
    readonly property var slot: root.host?.skinData ?? ({})
    // The sticker's own box in the host, so the marks stand off the icon and not off the whole slot.
    readonly property rect box: root.slot.box ?? Qt.rect(0, 0, root.width, root.height)
    readonly property int launches: root.slot.launches ?? 0
    // How far the sticker runs out of register; the host carries its icon by it.
    readonly property int shift: root.pressed ? Airisu.registration : run.dx

    onLaunchesChanged: if (root.launches > 0) run.run()

    ARegistration {
        id: run
        reach: Airisu.registration
    }
    ATombo {
        x: Math.round(root.box.x)
        y: Math.round(root.box.y)
        width: Math.round(root.box.width)
        height: Math.round(root.box.height)
        length: Airisu.m
        air: Airisu.hair
        shown: root.hovered && !root.pressed
    }
}
