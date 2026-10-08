pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.iris.components
import qs.modules.iris.style

ColumnLayout {
    id: root
    required property string side
    readonly property var sections: Config.options?.iris?.sidebars?.[root.side]?.sections
        ?? (root.side === "left" ? ["media", "tasks", "notes"] : ["calendar", "weather", "notifications"])
    readonly property var catalog: [
        { id: "media", label: "Now playing", icon: "music_note" },
        { id: "tasks", label: "Tasks", icon: "check_circle" },
        { id: "notes", label: "Notes", icon: "edit_note" },
        { id: "calendar", label: "Calendar", icon: "calendar_month" },
        { id: "weather", label: "Weather", icon: "partly_cloudy_day" },
        { id: "notifications", label: "Notifications", icon: "notifications" },
        { id: "focus", label: "Focus timer", icon: "timer" },
        { id: "mixer", label: "Sound mixer", icon: "graphic_eq" },
        { id: "system", label: "System", icon: "monitor_heart" }
    ]
    property var order: []
    function syncOrder(): void {
        const kept = root.order.filter(id => root.sections.includes(id))
        if (kept.length === root.sections.length && kept.every((id, i) => id === root.sections[i])) return
        root.order = root.sections.concat(root.catalog.map(s => s.id).filter(id => !root.sections.includes(id)))
    }
    onSectionsChanged: root.syncOrder()
    Component.onCompleted: root.syncOrder()
    readonly property var ordered: root.order.map(id => root.catalog.find(s => s.id === id)).filter(Boolean)
    spacing: 4 * IrisStyle.density

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
    Repeater {
        model: root.ordered
        RowLayout {
            id: row
            required property var modelData
            readonly property int position: root.sections.indexOf(row.modelData.id)
            Layout.fillWidth: true
            spacing: 4 * IrisStyle.density
            IrisIconButton {
                materialIcon: row.modelData.icon
                selected: row.position >= 0
                Accessible.name: Translation.tr(row.modelData.label)
                onClicked: root.toggle(row.modelData.id)
            }
            IrisButton {
                Layout.fillWidth: true
                quiet: true
                text: Translation.tr(row.modelData.label)
                selected: row.position >= 0
                onClicked: root.toggle(row.modelData.id)
            }
            IrisIconButton {
                materialIcon: "arrow_upward"
                enabled: row.position > 0
                opacity: enabled ? 1 : 0.25
                Accessible.name: Translation.tr("Move up")
                onClicked: root.move(row.modelData.id, -1)
            }
            IrisIconButton {
                materialIcon: "arrow_downward"
                enabled: row.position >= 0 && row.position < root.sections.length - 1
                opacity: enabled ? 1 : 0.25
                Accessible.name: Translation.tr("Move down")
                onClicked: root.move(row.modelData.id, 1)
            }
        }
    }
}
