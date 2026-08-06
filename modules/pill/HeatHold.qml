import QtQuick
import qs.modules.common

/**
 * Hold-to-confirm heat shared by the destructive gestures (power tiles,
 * wallpaper trash, clipboard wipe): `hold` fills 0→1 over PillMotion.heat while
 * pressed, fires `confirmed` when full and drains on release or exit. A
 * release before the fill completes drains; one shorter than `tapThreshold`
 * additionally fires `tapped` for sites whose hitbox doubles as a click
 * target. The fired latch keeps a release shortly after a confirm from being
 * misread as a tap while the drain is still running.
 */
Item {
    id: root

    visible: false

    property real hold: 0
    readonly property bool holding: hold > 0.001
    property real tapThreshold: 0
    property bool fired: false

    signal confirmed()
    signal tapped()

    function press() {
        fired = false;
        drain.stop();
        fill.restart();
    }

    function release() {
        fill.stop();
        if (fired || hold >= 1)
            return;
        if (tapThreshold > 0 && hold < tapThreshold)
            tapped();
        drain.restart();
    }

    function cancel() {
        fill.stop();
        drain.restart();
    }

    NumberAnimation {
        id: fill
        target: root
        property: "hold"
        from: 0
        to: 1
        /**
         * Never let the animation gate collapse this to zero: with animations off
         * PillMotion.heat is 0, and a destructive tile would confirm on the press
         * edge instead of a deliberate hold.
         */
        duration: Math.max(700, PillMotion.heat)
        onFinished: {
            root.fired = true;
            root.confirmed();
            drain.restart();
        }
    }

    NumberAnimation {
        id: drain
        target: root
        property: "hold"
        to: 0
        duration: Math.round(180 * PillMotion.mult)
    }
}
