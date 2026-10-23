pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.field as Field

// Arranging the desktop on one output: the shelf, a chosen widget's controls and the lights on what a carried widget
// meets, in a window above the chassis. The chassis and the desktop recede into the card under it, so everything here
// keeps its true size: the shelf is read and touched as itself, never shrunk.
PanelWindow {
    id: root

    signal gone()

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:iris-edit"
    WlrLayershell.keyboardFocus: bar.holdsKeyboard || sheet.typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { left: true; right: true; top: true; bottom: true }

    readonly property string outputName: root.screen?.name ?? ""
    readonly property var card: DesktopEditStage.cardFor(root.outputName, root.width, root.height)
    readonly property bool leaving: !GlobalStates.widgetEditMode && !bar.shown && !sheet.shown
    onLeavingChanged: if (root.leaving) Qt.callLater(root.gone)

    mask: Region {
        item: shelfHit
        Region { item: sheetHit }
        Region { item: chosen.item?.keysItem ?? null }
    }
    Item {
        id: shelfHit
        x: bar.hitRect.x
        y: bar.hitRect.y
        width: bar.hitRect.width
        height: bar.hitRect.height
    }
    Item {
        id: sheetHit
        x: sheet.hitRect.x
        y: sheet.hitRect.y
        width: sheet.hitRect.width
        height: sheet.hitRect.height
    }

    readonly property var fieldShapes: bar.fieldShapes.concat(sheet.fieldShapes)
    Field.IrisField {
        id: field
        anchors.fill: parent
        framed: false
        compositorAllowed: true
        providesBackdrop: true
        shapes: root.fieldShapes
    }
    Field.IrisBlurRegion {
        window: root
        shapes: root.fieldShapes.filter(shape => field.glassOf(shape) === 2 && !(shape.frost < 0.5))
        windowWidth: root.width
        windowHeight: root.height
    }

    // What a carried widget lines up with on the card lights in accent: the bodies are the chassis's, drawn shrunk
    // under this window, so their rims are drawn here where they show.
    IrisEditStage {
        anchors.fill: parent
        side: "lit"
        output: root.outputName
        card: root.card
    }

    // The chosen widget's ring, name and keys, and the name of the one under the pointer, over the card at true size.
    component Outfit: Loader {
        id: outfit
        property var entry: null
        readonly property Item widget: outfit.entry?.output === root.outputName ? outfit.entry.widget : null
        active: outfit.widget !== null
        x: root.card.x + (outfit.widget?.x ?? 0) * root.card.s
        y: root.card.y + (outfit.widget?.y ?? 0) * root.card.s
        width: (outfit.widget?.width ?? 0) * root.card.s
        height: (outfit.widget?.height ?? 0) * root.card.s
        sourceComponent: IrisWidgetOutfit {
            overlay: true
            widget: outfit.widget
            width: outfit.width
            height: outfit.height
            x: 0
            y: 0
            room: Qt.rect(0, 0, root.width, bar.hitRect.height > 0 ? bar.hitRect.y : root.height)
        }
    }
    Outfit {
        entry: DesktopEditStage.pointed?.widget !== DesktopEditStage.chosen?.widget ? DesktopEditStage.pointed : null
    }
    Outfit {
        id: chosen
        entry: DesktopEditStage.chosen
    }

    IrisWidgetBar {
        id: bar
        anchors.fill: parent
        screenData: root.screen
    }

    IrisWidgetSheet {
        id: sheet
        anchors.fill: parent
        outputName: root.outputName
        card: root.card
        avoid: bar.hitRect
    }
}
