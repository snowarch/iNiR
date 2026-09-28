pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.iris.style

QtObject {
    id: root

    readonly property var options: Config.options?.iris?.lock ?? ({})
    readonly property var scene: root.options?.scene ?? ({})
    readonly property var typeOptions: root.options?.type ?? ({})
    readonly property string material: String(root.options?.material ?? "glass")

    readonly property var blocks: [
        { id: "clock", label: "Clock", description: "The time, with the date over it." },
        { id: "glance", label: "At a glance", description: "The weather, what is next and the battery, as glass chips." },
        { id: "media", label: "Now playing", description: "Cover, title and transport while something plays." },
        { id: "activity", label: "Activity", description: "A recording or a running timer, as a plate." },
        { id: "session", label: "Sign in", description: "Your avatar, your name and the password field." },
        { id: "status", label: "Status", description: "Battery, network and keyboard layout." }
    ]
    readonly property var blockIds: root.blocks.map(block => block.id)
    readonly property var zones: ["top", "center", "bottom", "topLeft", "topRight", "bottomLeft", "bottomRight", "left", "right"]

    readonly property var groups: ["Layouts", "Scene", "Type", "Clock", "At a glance", "Widgets", "Now playing", "Activity", "Sign in", "Status"]
    readonly property var groupByBlock: ({ clock: "Clock", glance: "At a glance", media: "Now playing", activity: "Activity",
        session: "Sign in", status: "Status" })
    function groupOf(id: string): string { return id.startsWith("widget:") ? "Widgets" : root.groupByBlock[id] ?? "Scene" }
    function blockForGroup(group: string): string {
        return root.blockIds.find(id => root.groupByBlock[id] === group) ?? ""
    }
    function blockOf(id: string): var { return root.blocks.find(block => block.id === id) ?? null }
    function labelOf(id: string): string { return root.blockOf(id)?.label ?? id }
    function entry(id: string): var { return root.options?.blocks?.[id] ?? ({}) }
    function enabled(id: string): bool { return Boolean(root.entry(id)?.enable ?? false) }
    function zoneOf(id: string): string { return String(root.entry(id)?.zone ?? "top") }
    function scaleOf(id: string): real {
        return Math.max(0.5, Math.min(2, Number(root.entry(id)?.scale ?? 100) / 100))
    }
    function path(id: string): string { return "iris.lock.blocks." + id }
    function write(id: string, values: var): void {
        const updates = ({ "iris.lock.preset": "custom" })
        for (const key of Object.keys(values)) updates[root.path(id) + "." + key] = values[key]
        Config.setNestedValues(updates)
    }

    readonly property var presets: [
        { id: "iris", label: "iRiS", description: "The clock and the day up top, the player and the sign-in below.",
            type: { clockSize: 112, clockWeight: 700 },
            blocks: { clock: { enable: true, zone: "top", style: "stack" }, glance: { enable: true, zone: "top" }, media: { enable: true, zone: "bottom", style: "card" },
                activity: { enable: true, zone: "top" }, session: { enable: true, zone: "bottom" }, status: { enable: false, zone: "topRight" } } },
        { id: "centered", label: "Centered", description: "Everything in one column in the middle, the status in its corner.",
            type: { clockSize: 128, clockWeight: 700 },
            blocks: { clock: { enable: true, zone: "center", style: "stack" }, glance: { enable: true, zone: "center" }, media: { enable: true, zone: "center", style: "card" },
                activity: { enable: true, zone: "topLeft" }, session: { enable: true, zone: "center" }, status: { enable: true, zone: "topRight" } } },
        { id: "corner", label: "Corner", description: "A big clock in the corner, the rest on the other side.",
            type: { clockSize: 144, clockWeight: 800 },
            blocks: { clock: { enable: true, zone: "bottomLeft", style: "stack" }, glance: { enable: true, zone: "bottomLeft" }, media: { enable: true, zone: "bottomRight", style: "card" },
                activity: { enable: true, zone: "topLeft" }, session: { enable: true, zone: "bottomRight" }, status: { enable: true, zone: "topRight" } } },
        { id: "minimal", label: "Minimal", description: "A large, light clock and the sign-in. Nothing else asks for attention.",
            type: { clockSize: 176, clockWeight: 200 },
            blocks: { clock: { enable: true, zone: "center", style: "inline" }, glance: { enable: false, zone: "center" }, media: { enable: false, zone: "top", style: "bare" },
                activity: { enable: true, zone: "top" }, session: { enable: true, zone: "bottom" }, status: { enable: false, zone: "topRight" } } }
    ]
    readonly property string presetId: String(root.options?.preset ?? "")
    function presetOf(id: string): var { return root.presets.find(entry => entry.id === id) ?? null }
    function applyPreset(id: string): bool {
        const preset = root.presetOf(id)
        if (!preset) return false
        const updates = ({ "iris.lock.preset": preset.id })
        for (const key of Object.keys(preset.type)) updates["iris.lock.type." + key] = preset.type[key]
        for (const block of Object.keys(preset.blocks))
            for (const key of Object.keys(preset.blocks[block])) updates[root.path(block) + "." + key] = preset.blocks[block][key]
        Config.setNestedValues(updates)
        return true
    }
    function widgetShown(screenName: string, key: string): bool {
        Config.revision
        return DesktopWidgetLayout.enabled(DesktopWidgetLayout.lockScope(screenName), key, false)
    }
    // A widget arrives on the lock where it sits on the desktop, placed freely so it can be moved.
    function toggleWidget(screenName: string, key: string): void {
        const scope = DesktopWidgetLayout.lockScope(screenName)
        if (root.widgetShown(screenName, key)) {
            DesktopWidgetLayout.setValues(scope, key, { enable: false })
            return
        }
        const x = Number(DesktopWidgetLayout.value(screenName, key, "x", 96))
        const y = Number(DesktopWidgetLayout.value(screenName, key, "y", 96))
        DesktopWidgetLayout.setValues(scope, key, { enable: true, placementStrategy: "free",
            x: Number.isFinite(x) ? x : 96, y: Number.isFinite(y) ? y : 96 })
    }
    function place(id: string, zone: string, fx: real, fy: real): void {
        root.write(id, { zone: zone, fx: Math.round(fx * 10000) / 10000, fy: Math.round(fy * 10000) / 10000 })
    }

    // Stacked in registry order inside a zone, so a shared zone reads as one column.
    // While editing, a block that is off still holds its seat as a ghost: a block you
    // cannot see is a block you cannot turn back on.
    function shown(zone: string, includeOff: bool): var {
        return root.blockIds.filter(id => (includeOff || root.enabled(id)) && root.zoneOf(id) === zone)
    }
    function loose(includeOff: bool): var {
        return root.blockIds.filter(id => (includeOff || root.enabled(id))
            && !root.zones.includes(root.zoneOf(id)))
    }
    function toggle(id: string): void { root.write(id, { enable: !root.enabled(id) }) }
    function nudge(id: string, dx: real, dy: real): void {
        const entry = root.entry(id)
        const zone = root.zoneOf(id)
        const fx = root.zones.includes(zone) ? 0.5 : Number(entry?.fx ?? 0.5)
        const fy = root.zones.includes(zone) ? 0.5 : Number(entry?.fy ?? 0.5)
        root.place(id, "free", Math.max(0, Math.min(1, fx + dx)), Math.max(0, Math.min(1, fy + dy)))
    }
    function zoneAnchor(zone: string, width: real, height: real, margin: real): var {
        const top = zone.startsWith("top")
        const bottom = zone.startsWith("bottom")
        const x = zone === "left" || zone.endsWith("Left") ? margin
            : zone === "right" || zone.endsWith("Right") ? width - margin : width / 2
        const y = top ? Math.round(height * 0.09) : bottom ? Math.round(height * 0.89) : height / 2
        return { x: x, y: y, up: bottom, align: zone === "left" || zone.endsWith("Left") ? Qt.AlignLeft
            : zone === "right" || zone.endsWith("Right") ? Qt.AlignRight : Qt.AlignHCenter }
    }

    readonly property real typeScale: Math.max(0.6, Math.min(1.6, Number(root.typeOptions?.scale ?? 100) / 100))
    readonly property string clockFamily: {
        const chosen = String(root.typeOptions?.clockFont ?? "numbers")
        return chosen === "main" ? IrisStyle.fontMain : chosen === "title" ? IrisStyle.fontTitle : IrisStyle.fontNumbers
    }
    readonly property color accentColour: {
        const chosen = String(root.typeOptions?.accent ?? "plain")
        if (chosen === "accent") return IrisStyle.accent
        if (chosen === "highlight") return IrisStyle.secondaryAccent
        return IrisStyle.onMedia
    }
}
