import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions

// The bench: the scrim, the strip, the open tools and the guides a drag snaps to. A click on the empty desk or Esc
// closes it; pinned tools stay as they are.
Item {
    id: root
    focus: true

    readonly property bool benchOpen: GlobalStates.overlayOpen
    readonly property real d: OverlayLook.d

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.overlayOpen = false
            event.accepted = true
        }
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: FamilyStyle.scrim
        opacity: root.benchOpen && (Config.options?.overlay?.darkenScreen ?? true) ? (Config.options?.overlay?.scrimDim ?? 35) / 100 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: OverlayLook.scrimDuration; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: desk
        anchors.fill: parent
        enabled: root.benchOpen
        // A press on a tool or the strip is theirs (a tool moves from its empty parts).
        onPressed: mouse => {
            const inStrip = mouse.x >= strip.x && mouse.x <= strip.x + strip.width && mouse.y >= strip.y && mouse.y <= strip.y + strip.height
            const onTool = OverlayContext.plates("").some(r => mouse.x >= r.x && mouse.x <= r.x + r.w && mouse.y >= r.y && mouse.y <= r.y + r.h)
            mouse.accepted = !inStrip && !onTool
        }
        onClicked: GlobalStates.overlayOpen = false
    }

    // The tools' canvas: a sibling of the desk, so a disabled desk never disables a pinned tool.
    Item {
        id: canvas
        anchors.fill: parent

        Repeater {
            model: ScriptModel {
                values: OverlayContext.openIds.map(identifier => OverlayContext.info(identifier)).filter(w => w !== null)
                objectProp: "identifier"
            }
            delegate: OverlayWidgetDelegateChooser {}
        }

        Rectangle {
            visible: OverlayContext.guideX >= 0
            x: Math.round(OverlayContext.guideX)
            width: 1
            height: parent.height
            z: 200000
            color: ColorUtils.applyAlpha(OverlayLook.colPrimary, 0.75)
        }
        Rectangle {
            visible: OverlayContext.guideY >= 0
            y: Math.round(OverlayContext.guideY)
            height: 1
            width: parent.width
            z: 200000
            color: ColorUtils.applyAlpha(OverlayLook.colPrimary, 0.75)
        }
    }

    OverlayTaskbar {
        id: strip
        property real shown: root.benchOpen ? 1 : 0
        Behavior on shown { NumberAnimation { duration: OverlayLook.openDuration; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(FamilyStyle.frameInset("top") + Math.round(14 * root.d), 40) - (1 - strip.shown) * Math.round(14 * root.d)
        opacity: strip.shown
        visible: strip.shown > 0.01
    }

    Binding {
        target: OverlayContext
        property: "deskTop"
        value: Math.max(FamilyStyle.frameInset("top") + Math.round(14 * root.d), 40) + strip.height + Math.round(20 * root.d)
    }
}
