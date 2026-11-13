pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// The chooser ColorPickerDialog shows: a saturation and brightness field over a hue strip, the colour before and
// now, its hex, the theme's colours and a small palette, and a dropper that takes one from the screen.
// Keys: arrows move in the field, Page Up/Down turn the hue, Enter chooses, Esc cancels.
Item {
    id: root

    property string title: ""
    property color startColor: "#808080"
    signal chosen(color picked)
    signal cancelled()
    // The dropper: the dialog steps aside, takes a colour from the screen and hands it to take().
    signal dropperRequested()

    readonly property real s: FamilyStyle.density

    property real hue: 0
    property real sat: 0
    property real val: 0.5
    readonly property color current: Qt.hsva(root.hue, root.sat, root.val, 1)

    function hexOf(c: color): string {
        const two = n => Math.round(n * 255).toString(16).padStart(2, "0")
        return ("#" + two(c.r) + two(c.g) + two(c.b)).toUpperCase()
    }
    function same(a: color, b: color): bool {
        return root.hexOf(a) === root.hexOf(b)
    }

    // A grey has no hue: the strip stays where it was.
    function take(c: color): void {
        if (c.hsvSaturation > 0 && c.hsvHue >= 0)
            root.hue = c.hsvHue
        root.sat = c.hsvSaturation
        root.val = c.hsvValue
    }

    function parse(text: string): var {
        let t = text.trim().replace(/^#/, "")
        if (/^[0-9a-fA-F]{3}$/.test(t))
            t = t.split("").map(ch => ch + ch).join("")
        return /^[0-9a-fA-F]{6}$/.test(t) ? Qt.color("#" + t) : null
    }

    function choose(): void {
        root.chosen(root.current)
    }

    function nudge(ds: real, dv: real): void {
        root.sat = Math.max(0, Math.min(1, root.sat + ds))
        root.val = Math.max(0, Math.min(1, root.val + dv))
    }

    function key(event: var): void {
        const step = (event.modifiers & Qt.ShiftModifier) ? 0.1 : 0.02
        if (event.key === Qt.Key_Escape)
            root.cancelled()
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            root.choose()
        else if (event.key === Qt.Key_Left)
            root.nudge(-step, 0)
        else if (event.key === Qt.Key_Right)
            root.nudge(step, 0)
        else if (event.key === Qt.Key_Up)
            root.nudge(0, step)
        else if (event.key === Qt.Key_Down)
            root.nudge(0, -step)
        else if (event.key === Qt.Key_PageUp)
            root.hue = (root.hue + step / 2 + 1) % 1
        else if (event.key === Qt.Key_PageDown)
            root.hue = (root.hue - step / 2 + 1) % 1
        else
            return
        event.accepted = true
    }

    Component.onCompleted: {
        root.take(root.startColor)
        field.forceActiveFocus()
    }
    onCurrentChanged: if (!hexInput.activeFocus) hexInput.text = root.hexOf(root.current)

    // The theme's own colours first, then a palette with one of each hue.
    readonly property var themeColors: [FamilyStyle.accent, FamilyStyle.secondaryAccent, FamilyStyle.highlightOnMedia,
        FamilyStyle.danger, FamilyStyle.success, "#FFFFFF", "#9E9E9E", "#3C3C3C", "#000000"]
    readonly property var paletteColors: ["#E5484D", "#F76B15", "#FFC53D", "#46A758", "#12A594", "#00A2C7", "#0090FF",
        "#6E56CF", "#D6409F"]

    ShellSheet {
        anchors.fill: parent
        cardWidth: 360 * root.s
        cardHeight: 476 * root.s
        onDismissed: root.cancelled()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(16 * root.s)
            spacing: Math.round(12 * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.s)
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.title.length > 0 ? root.title : Translation.tr("Choose a colour")
                    color: FamilyStyle.textStrong
                    font.family: FamilyStyle.fontTitle
                    font.pixelSize: FamilyStyle.typeLabel
                    font.weight: Font.DemiBold
                }
                SheetButton {
                    glyph: "colorize"
                    tip: Translation.tr("Take a colour from the screen")
                    onClicked: root.dropperRequested()
                }
            }

            // Saturation across, brightness up, over the hue.
            ClippingRectangle {
                id: field
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: FamilyStyle.radiusTile
                color: Qt.hsva(root.hue, 1, 1, 1)
                focus: true
                activeFocusOnTab: true
                Keys.onPressed: event => root.key(event)
                Accessible.role: Accessible.Slider
                Accessible.name: Translation.tr("Saturation and brightness")

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#FFFFFFFF" }
                        GradientStop { position: 1; color: "#00FFFFFF" }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#00000000" }
                        GradientStop { position: 1; color: "#FF000000" }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    function at(x: real, y: real): void {
                        root.sat = Math.max(0, Math.min(1, x / width))
                        root.val = Math.max(0, Math.min(1, 1 - y / height))
                    }
                    onPressed: mouse => {
                        field.forceActiveFocus()
                        at(mouse.x, mouse.y)
                    }
                    onPositionChanged: mouse => at(mouse.x, mouse.y)
                }
                Rectangle {
                    readonly property real size: Math.round(18 * root.s)
                    x: Math.round(root.sat * field.width - size / 2)
                    y: Math.round((1 - root.val) * field.height - size / 2)
                    width: size
                    height: size
                    radius: size / 2
                    color: root.current
                    border.width: 2
                    border.color: "#FFFFFF"
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -1
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: "#59000000"
                    }
                }
            }

            // The hue.
            Rectangle {
                id: hueStrip
                Layout.fillWidth: true
                implicitHeight: Math.round(14 * root.s)
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0 / 6; color: Qt.hsva(0 / 6, 1, 1, 1) }
                    GradientStop { position: 1 / 6; color: Qt.hsva(1 / 6, 1, 1, 1) }
                    GradientStop { position: 2 / 6; color: Qt.hsva(2 / 6, 1, 1, 1) }
                    GradientStop { position: 3 / 6; color: Qt.hsva(3 / 6, 1, 1, 1) }
                    GradientStop { position: 4 / 6; color: Qt.hsva(4 / 6, 1, 1, 1) }
                    GradientStop { position: 5 / 6; color: Qt.hsva(5 / 6, 1, 1, 1) }
                    GradientStop { position: 6 / 6; color: Qt.hsva(0, 1, 1, 1) }
                }
                Accessible.role: Accessible.Slider
                Accessible.name: Translation.tr("Hue")
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -Math.round(6 * root.s)
                    anchors.bottomMargin: -Math.round(6 * root.s)
                    cursorShape: Qt.PointingHandCursor
                    function at(x: real): void {
                        root.hue = Math.max(0, Math.min(0.9999, x / width))
                    }
                    onPressed: mouse => {
                        field.forceActiveFocus()
                        at(mouse.x)
                    }
                    onPositionChanged: mouse => at(mouse.x)
                }
                Rectangle {
                    readonly property real size: Math.round(20 * root.s)
                    x: Math.round(root.hue * hueStrip.width - size / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: size
                    height: size
                    radius: size / 2
                    color: Qt.hsva(root.hue, 1, 1, 1)
                    border.width: 2
                    border.color: "#FFFFFF"
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -1
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: "#59000000"
                    }
                }
            }

            // Before and now, and the hex.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(2 * root.s)
                spacing: Math.round(8 * root.s)

                ClippingRectangle {
                    implicitWidth: Math.round(64 * root.s)
                    implicitHeight: Math.round(34 * root.s)
                    radius: FamilyStyle.radiusRow
                    color: "transparent"
                    border.width: 1
                    border.color: FamilyStyle.border
                    Row {
                        anchors.fill: parent
                        MouseArea {
                            width: parent.width / 2
                            height: parent.height
                            cursorShape: root.same(root.startColor, root.current) ? Qt.ArrowCursor : Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: Translation.tr("Back to the colour it had")
                            onClicked: root.take(root.startColor)
                            Rectangle {
                                anchors.fill: parent
                                color: root.startColor
                            }
                        }
                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            color: root.current
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(34 * root.s)
                    radius: FamilyStyle.radiusRow
                    color: hexInput.activeFocus ? FamilyStyle.fillHover : FamilyStyle.fillQuiet
                    border.width: hexInput.activeFocus ? 1 : 0
                    border.color: ColorUtils.applyAlpha(FamilyStyle.accent, 0.6)
                    TextInput {
                        id: hexInput
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(12 * root.s)
                        anchors.rightMargin: Math.round(12 * root.s)
                        verticalAlignment: TextInput.AlignVCenter
                        maximumLength: 7
                        clip: true
                        color: FamilyStyle.textStrong
                        selectionColor: ColorUtils.applyAlpha(FamilyStyle.accent, 0.35)
                        selectedTextColor: FamilyStyle.textStrong
                        font.family: FamilyStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: FamilyStyle.typeMeta
                        font.capitalization: Font.AllUppercase
                        Component.onCompleted: hexInput.text = root.hexOf(root.current)
                        onTextEdited: {
                            const typed = root.parse(hexInput.text)
                            if (typed)
                                root.take(typed)
                        }
                        onAccepted: root.choose()
                        onActiveFocusChanged: if (!activeFocus) hexInput.text = root.hexOf(root.current)
                        Keys.onEscapePressed: event => {
                            field.forceActiveFocus()
                            event.accepted = true
                        }
                    }
                    // The first click takes the whole hex, ready to be typed over; later clicks place the cursor.
                    MouseArea {
                        anchors.fill: parent
                        visible: !hexInput.activeFocus
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            hexInput.forceActiveFocus()
                            hexInput.selectAll()
                        }
                    }
                }
            }

            // The theme's colours, then the palette, spread edge to edge.
            Repeater {
                model: [root.themeColors, root.paletteColors]
                Item {
                    id: swatchRow
                    required property var modelData
                    readonly property real cell: Math.round(24 * root.s)
                    readonly property real pitch: (swatchRow.width - swatchRow.cell) / Math.max(1, swatchRow.modelData.length - 1)
                    Layout.fillWidth: true
                    implicitHeight: swatchRow.cell
                    Repeater {
                        model: swatchRow.modelData
                        MouseArea {
                            id: swatch
                            required property var modelData
                            required property int index
                            readonly property bool on: root.same(swatch.modelData, root.current)
                            x: Math.round(swatch.index * swatchRow.pitch)
                            width: swatchRow.cell
                            height: swatchRow.cell
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: root.hexOf(swatch.modelData)
                            onClicked: root.take(swatch.modelData)
                            onDoubleClicked: root.choose()
                            Rectangle {
                                anchors.centerIn: parent
                                width: swatch.on ? parent.width - Math.round(8 * root.s) : swatch.containsMouse ? parent.width + 2 : parent.width
                                height: width
                                radius: width / 2
                                color: swatch.modelData
                                border.width: 1
                                border.color: ColorUtils.applyAlpha(FamilyStyle.text, 0.14)
                                Behavior on width { NumberAnimation { duration: FamilyStyle.feedbackDuration; easing.type: Easing.OutCubic } }
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: swatch.on
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: FamilyStyle.accent
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(4 * root.s)
                spacing: Math.round(8 * root.s)
                Item { Layout.fillWidth: true }
                SheetButton {
                    label: Translation.tr("Cancel")
                    onClicked: root.cancelled()
                }
                SheetButton {
                    label: Translation.tr("Choose")
                    strong: true
                    onClicked: root.choose()
                }
            }
        }
    }
}
