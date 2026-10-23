import QtQuick
import QtQuick.Layouts
import qs.modules.iris.style

// The Signal set on one sheet (DESIGN.md S2, S4): the three voices and every control in its states, as the proof
// bench renders them under the Design and scheme in use.
GridLayout {
    id: root
    readonly property real d: IrisStyle.density
    columns: 2
    columnSpacing: Math.round(40 * root.d)
    rowSpacing: Math.round(22 * root.d)

    component Cell: ColumnLayout {
        property string caption: ""
        spacing: Math.round(10 * root.d)
        Layout.alignment: Qt.AlignTop
        IrisLabel { text: parent.caption }
    }

    Cell {
        caption: "Figure · Archivo SemiExpanded"
        IrisDotText { text: "12:44"; pixelSize: IrisStyle.typeDotXL }
        Row {
            spacing: Math.round(10 * root.d)
            IrisDotText { id: share; text: "72%"; pixelSize: IrisStyle.typeDotM }
            IrisLabel { text: "Dock"; anchors.bottom: share.bottom; anchors.bottomMargin: Math.round(6 * root.d) }
        }
    }
    Cell {
        caption: "Read · Geist 400/500/600 · Label · Geist Mono"
        IrisText { role: IrisText.Display; text: "Dock" }
        IrisText { role: IrisText.Meta; text: "Where your apps wait. It hides when a window needs the room." }
        IrisText { role: IrisText.Title; text: "Behaviour" }
        IrisText { role: IrisText.Name; text: "Hide automatically" }
        IrisText { role: IrisText.Detail; text: "Comes back when the pointer touches the edge." }
        Row {
            spacing: Math.round(10 * root.d)
            Repeater {
                model: [IrisStyle.text, IrisStyle.subtext, IrisStyle.textTertiary, IrisStyle.fill, IrisStyle.signal]
                Rectangle { required property color modelData; width: Math.round(24 * root.d); height: width; radius: width / 2; color: modelData; border.width: 1; border.color: IrisStyle.hairline }
            }
        }
    }
    Cell {
        caption: "Switch · off / on"
        Row {
            spacing: Math.round(14 * root.d)
            IrisSwitch { on: false }
            IrisSwitch { on: true }
        }
    }
    Cell {
        caption: "Segmented · chosen is inverted"
        IrisSegmented {
            implicitWidth: fitWidth
            options: [{ value: "auto", label: "Auto" }, { value: "bottom", label: "Bottom" }, { value: "left", label: "Left" }, { value: "right", label: "Right" }]
            current: "auto"
        }
    }
    Cell {
        caption: "Range · dot scrubber, value as label"
        IrisScrubber {
            Layout.preferredWidth: Math.round(260 * root.d)
            knob: true
            showValue: true
            value: 0.4
            range: ({ min: 16, max: 64, step: 1, value: 40, text: "40 px" })
        }
    }
    Cell {
        caption: "Meter · progress · working"
        IrisDotStrip { Layout.preferredWidth: Math.round(160 * root.d); value: 0.6 }
        IrisDotStrip { Layout.preferredWidth: Math.round(160 * root.d); indeterminate: true }
    }
    Cell {
        caption: "Buttons · primary, secondary, destructive"
        Row {
            spacing: Math.round(8 * root.d)
            IrisButton { text: "Apply"; emphasized: true }
            IrisButton { text: "Cancel" }
            IrisButton { text: "Remove"; danger: true }
        }
    }
    Cell {
        caption: "Tiles · 1x1 / 2x1, live dot"
        Row {
            spacing: Math.round(8 * root.d)
            IrisTile { on: true; glyph: "wifi"; label: "Wi-Fi" }
            IrisTile { glyph: "bluetooth"; label: "BT" }
            IrisTile { wide: true; live: true; title: "Recording"; figure: "02:14" }
        }
    }
    Cell {
        caption: "Paper · 8 px dot grid"
        Rectangle {
            Layout.preferredWidth: Math.round(260 * root.d)
            Layout.preferredHeight: Math.round(72 * root.d)
            radius: IrisStyle.radiusTile
            color: IrisStyle.fillQuiet
            clip: true
            IrisDotGrid { anchors.fill: parent }
        }
    }
    Cell {
        caption: "Signal"
        Row {
            spacing: Math.round(10 * root.d)
            Rectangle { width: Math.round(8 * root.d); height: width; radius: width / 2; color: IrisStyle.signal; anchors.verticalCenter: parent.verticalCenter }
            IrisText { role: IrisText.Name; text: "Dock pins an app that isn't installed" }
        }
    }
}
