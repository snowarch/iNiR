pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// A panel's sections read as Settings rows: the section's mark and name, a switch, and for what is shown the order
// steps beside it. Shown sections lead in their order; the rest follow, quiet, one switch away.
Rectangle {
    id: root
    required property string side
    // The group's fill: a reading card in Settings, the panel's quiet fill inside the panel itself.
    property color plate: IrisStyle.readingCard
    readonly property real d: IrisStyle.density
    readonly property var sections: Config.options?.iris?.sidebars?.[root.side]?.sections
        ?? (root.side === "left" ? ["media", "tasks", "notes"] : ["calendar", "weather", "notifications"])
    // Getters: a list that feeds Settings holds no live colour.
    readonly property var catalog: [
        { id: "media", label: "Now playing", icon: "music_note", get tint() { return IrisStyle.identity.pink } },
        { id: "tasks", label: "Tasks", icon: "check_circle", get tint() { return IrisStyle.identity.green } },
        { id: "notes", label: "Notes", icon: "edit_note", get tint() { return IrisStyle.identity.yellow } },
        { id: "calendar", label: "Calendar", icon: "calendar_month", get tint() { return IrisStyle.identity.red } },
        { id: "weather", label: "Weather", icon: "partly_cloudy_day", get tint() { return IrisStyle.identity.sky } },
        { id: "notifications", label: "Notifications", icon: "notifications", get tint() { return IrisStyle.identity.orange } },
        { id: "focus", label: "Focus timer", icon: "timer", get tint() { return IrisStyle.identity.indigo } },
        { id: "mixer", label: "Sound mixer", icon: "graphic_eq", get tint() { return IrisStyle.identity.purple } },
        { id: "system", label: "System", icon: "monitor_heart", get tint() { return IrisStyle.identity.teal } }
    ]
    property var order: []
    function syncOrder(): void {
        const kept = root.order.filter(id => root.sections.includes(id))
        // The order always holds the whole catalogue: with every section off it was empty and kept nothing to switch on.
        if (root.order.length === root.catalog.length && kept.length === root.sections.length
            && kept.every((id, i) => id === root.sections[i])) return
        root.order = root.sections.concat(root.catalog.map(s => s.id).filter(id => !root.sections.includes(id)))
    }
    onSectionsChanged: root.syncOrder()
    Component.onCompleted: root.syncOrder()
    readonly property var ordered: root.order.map(id => root.catalog.find(s => s.id === id)).filter(Boolean)

    function write(order: var): void {
        root.order = order
        Config.setNestedValue("iris.sidebars." + root.side + ".sections", order.filter(id => root.sections.includes(id)))
    }
    function toggle(id: string): void {
        const on = root.sections.includes(id)
        Config.setNestedValue("iris.sidebars." + root.side + ".sections",
            root.order.filter(s => s === id ? !on : root.sections.includes(s)))
    }
    function move(id: string, delta: int): void {
        const enabled = root.order.filter(s => root.sections.includes(s))
        const index = enabled.indexOf(id)
        const other = enabled[index + delta]
        if (index < 0 || other === undefined) return
        const next = [...root.order]
        const a = next.indexOf(id)
        const b = next.indexOf(other)
        next[a] = other
        next[b] = id
        root.write(next)
    }

    implicitHeight: list.implicitHeight
    radius: IrisStyle.radiusTile
    color: root.plate

    Column {
        id: list
        width: root.width
        Repeater {
            model: root.ordered
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property int position: root.sections.indexOf(row.modelData.id)
                readonly property bool shown: row.position >= 0
                width: list.width
                height: Math.round(46 * root.d)

                // The section's glyph in its colour, no tile under it: the same mark Settings gives its areas and links.
                MaterialSymbol {
                    id: mark
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(14 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(26 * root.d)
                    horizontalAlignment: Text.AlignHCenter
                    text: row.modelData.icon
                    iconSize: Math.round(19 * root.d)
                    color: IrisStyle.plainMarks ? IrisStyle.textSecondary : row.modelData.tint
                    opacity: row.shown ? 1 : 0.4
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                }
                IrisText {
                    anchors.left: mark.right
                    anchors.leftMargin: Math.round(12 * root.d)
                    anchors.right: steps.left
                    anchors.rightMargin: Math.round(8 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Translation.tr(row.modelData.label)
                    color: row.shown ? IrisStyle.text : IrisStyle.muted
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.Medium)
                    elide: Text.ElideRight
                }
                Row {
                    id: steps
                    anchors.right: toggle.left
                    anchors.rightMargin: Math.round(8 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.shown
                    width: visible ? implicitWidth : 0
                    spacing: 0
                    IrisIconButton {
                        implicitWidth: Math.round(30 * root.d)
                        iconSize: Math.round(18 * root.d)
                        materialIcon: "keyboard_arrow_up"
                        enabled: row.position > 0
                        opacity: enabled ? 1 : 0.3
                        Accessible.name: Translation.tr("Move up")
                        onClicked: root.move(row.modelData.id, -1)
                    }
                    IrisIconButton {
                        implicitWidth: Math.round(30 * root.d)
                        iconSize: Math.round(18 * root.d)
                        materialIcon: "keyboard_arrow_down"
                        enabled: row.position < root.sections.length - 1
                        opacity: enabled ? 1 : 0.3
                        Accessible.name: Translation.tr("Move down")
                        onClicked: root.move(row.modelData.id, 1)
                    }
                }
                IrisSwitch {
                    id: toggle
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(14 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    on: row.shown
                    name: Translation.tr(row.modelData.label)
                    onToggled: root.toggle(row.modelData.id)
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(52 * root.d)
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    visible: row.index < root.ordered.length - 1
                    color: IrisStyle.hairline
                }
            }
        }
    }
}
