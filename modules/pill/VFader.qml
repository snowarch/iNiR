import QtQuick
import qs.modules.common

/**
 * Vertical filament fader. A thin matte thread with a rising fill and a flat
 * tick marker. Dim at rest; saturates and reveals its readout when focused.
 * Hover targeting is owned by the parent surface, which maps pointer position
 * to a fader column and drives `focused`. No knob, no glow. Value is 0..1.
 */
Item {
    id: root

    property real s: 1
    property string icon: ""
    property real value: 0.5
    property string valueLabel: ""
    property string subLabel: ""
    property bool subPersistent: true
    property bool focused: false

    /**
     * Mute affordance. When `iconClickable` the glyph under the track is a
     * button (its owner flips the mute and feeds `muted` back); a muted fader
     * keeps its level but burns cold: dim fill, dim glyph.
     */
    property bool muted: false
    property bool iconClickable: false

    signal moved(real v)
    signal committed(real v)
    signal iconClicked()

    readonly property bool lit: focused

    readonly property real trackH: 86 * s

    /**
     * Live tick centre in this fader's coordinates. tick.y and root.width are
     * voided because mapToItem creates no QML dependency on the source item's
     * transform; without them the binding snapshots the tick where it first
     * rendered and the bead docks at a stale height after a value change and a
     * stale x after the mixer resizes.
     */
    readonly property point tickCenter: {
        void tick.y;
        void root.width;
        return tick.mapToItem(root, tick.width / 2, tick.height / 2);
    }

    implicitWidth: 54 * s
    implicitHeight: trackH + (subLabel.length ? 56 : 44) * s

    /**
     * Nudge the value by a signed percentage (e.g. +1 / -1), clamped to 0..100%,
     * emitting `moved` and `committed` so live hardware updates on each step.
     */
    function step(deltaPct) {
        const v = Math.max(0, Math.min(1, root.value + deltaPct / 100));
        root.moved(v);
        root.committed(v);
    }

    Item {
        id: trackArea
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 22 * root.s
        height: root.trackH

        Rectangle {
            id: thread
            anchors.horizontalCenter: parent.horizontalCenter
            width: 2 * root.s
            height: parent.height
            radius: width / 2
            color: PillTheme.threadBg

            Rectangle {
                id: fill
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * Math.max(0, Math.min(1, root.value))
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.muted ? PillTheme.vermDim : (root.lit ? PillTheme.vermLit : PillTheme.vermDim) }
                    GradientStop { position: 1.0; color: root.muted ? PillTheme.vermDimDeep : (root.lit ? PillTheme.vermBurn : PillTheme.vermDimDeep) }
                }
                opacity: root.muted ? 0.55 : 1
                Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
                Behavior on height { enabled: !dragArea.pressed; NumberAnimation { duration: PillMotion.fast } }
            }
        }

        Rectangle {
            id: tick
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, Math.min(root.trackH - height,
                (1 - Math.max(0, Math.min(1, root.value))) * root.trackH - height / 2))
            width: 11 * root.s
            height: 2.5 * root.s
            radius: 2 * root.s
            color: PillTheme.tickRest
            opacity: root.focused ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
            Behavior on y { enabled: !dragArea.pressed; NumberAnimation { duration: PillMotion.fast } }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.margins: -10 * root.s
            preventStealing: true
            function setFromY(my) {
                const v = 1 - Math.max(0, Math.min(1, (my - 10 * root.s) / root.trackH));
                root.moved(v);
            }
            onPressed: (e) => setFromY(e.y)
            onPositionChanged: (e) => { if (pressed) setFromY(e.y); }
            onReleased: root.committed(root.value)
        }
    }

    Text {
        id: readout
        anchors.top: trackArea.bottom
        anchors.topMargin: 7 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.valueLabel
        color: root.lit ? PillTheme.cream : PillTheme.dim
        opacity: root.lit ? 1 : 0
        font.family: PillTheme.font
        font.pixelSize: 9 * root.s
        font.weight: Font.DemiBold
        // Percent readouts that tick while dragging; without tabular figures the
        // label jitters horizontally as digit widths change.
        font.features: { "tnum": 1 }
        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
    }

    Item {
        id: iconBox
        anchors.top: readout.bottom
        anchors.topMargin: 3 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: 18 * root.s
        height: 18 * root.s

        GlyphIcon {
            anchors.fill: parent
            name: root.icon
            color: root.muted ? PillTheme.dim : (root.lit ? PillTheme.cream : PillTheme.iconDim)
            stroke: 1.7
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -5 * root.s
            enabled: root.iconClickable
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    Text {
        visible: root.subLabel.length > 0
        opacity: root.subPersistent || root.lit ? 1 : 0
        anchors.top: iconBox.bottom
        anchors.topMargin: 1 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.subLabel
        color: root.lit ? PillTheme.cream : PillTheme.faint
        font.family: PillTheme.font
        font.pixelSize: 9 * root.s
        font.weight: Font.DemiBold
        font.letterSpacing: 0.3 * root.s
        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
    }
}
