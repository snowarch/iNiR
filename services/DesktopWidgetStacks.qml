pragma Singleton
pragma ComponentBehavior: Bound

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

/**
 * DesktopWidgetStacks - iRiS widget stacks: several widgets sharing one place, one page shown at a time.
 *
 * A stack is a list of widget keys in `background.widgets.stacks`. The widgets stay what they are; the
 * stack owns what must be one for all of them (place, size class, material, corners, lock), kept in
 * `outputOverrides` under the pseudo widget "stack:<id>" so every output has its own. DesktopWidgetLayout
 * asks `owner()` for whose record a value lives in. Nothing of this applies outside the iRiS design
 * (`live`): elsewhere every widget stands where it was, and the lock screen never stacks.
 *
 * Which page is shown is runtime state (`pages`), never persisted. Rotation is one Timer per stack, held
 * while the pointer is over it, while arranging, and while no output shows it (covered, paused, fullscreen).
 */
Singleton {
    id: root

    readonly property var sharedKeys: ({
        "x": true, "y": true, "placementStrategy": true, "widgetScale": true, "locked": true,
        "iris.size": true, "iris.material": true, "iris.opacity": true, "cornerRadius": true
    })
    readonly property var sizeOrder: ["small", "medium", "large"]
    readonly property var intervals: [10, 20, 30, 60, 300]
    readonly property int defaultInterval: 20
    readonly property string prefix: "stack:"

    readonly property bool live: (Config.options?.panelFamily ?? "ii") === "iris"
        && !["material", "instrument", "readout"].includes(String(Config.options?.iris?.widgets?.design ?? "iris"))

    readonly property var stacks: {
        const raw = Config.options?.background?.widgets?.stacks ?? []
        const found = []
        const taken = ({})
        for (let i = 0; i < raw.length; ++i) {
            const entry = raw[i]
            if (!entry || typeof entry !== "object" || !entry.id)
                continue
            const members = []
            for (const key of Array.from(entry.members ?? [])) {
                const name = String(key)
                if (name.length > 0 && taken[name] === undefined && members.indexOf(name) < 0)
                    members.push(name)
            }
            if (members.length < 2)
                continue
            for (const name of members)
                taken[name] = true
            found.push({
                id: String(entry.id),
                members: members,
                rotate: entry.rotate !== false,
                interval: Math.max(5, Math.min(3600, Math.round(Number(entry.interval ?? root.defaultInterval)) || root.defaultInterval)),
                size: String(entry.size ?? "")
            })
        }
        return found
    }
    readonly property var memberMap: {
        const map = ({})
        for (const stack of root.stacks)
            for (const key of stack.members)
                map[key] = stack.id
        return map
    }

    // stack id -> { key, dir, serial }: the page shown. Runtime only.
    property var pages: ({})
    property var hovering: ({})
    // widget key -> { sizes, size, faced }: what each loaded widget says about itself.
    property var reported: ({})
    // widgets that just left a stack; the canvas finds them a free spot beside it.
    property var splits: ({})
    readonly property bool splitPending: Object.keys(root.splits).length > 0

    function stackById(id: string): var {
        for (const stack of root.stacks)
            if (stack.id === id)
                return stack
        return null
    }

    function stackOf(widgetKey: string): var {
        const id = root.memberMap[String(widgetKey ?? "")]
        return id === undefined ? null : root.stackById(id)
    }

    function _lock(output: string): bool {
        return String(output ?? "").startsWith("lock:")
    }

    // Whose record holds `valueKey` of `widgetKey` on `output`.
    function owner(output: string, widgetKey: string, valueKey: string): string {
        if (!root.live || root.sharedKeys[valueKey] === undefined || root._lock(output))
            return widgetKey
        const id = root.memberMap[widgetKey]
        return id === undefined ? widgetKey : root.prefix + id
    }

    function _isEnabled(output: string, key: string): bool {
        return DesktopWidgetLayout.enabled(output, key, Config.getNestedValue("background.widgets." + key + ".enable", false))
    }

    function pagesOn(output: string, id: string): var {
        void Config.revision
        const stack = root.stackById(id)
        if (!stack)
            return []
        return stack.members.filter(key => root._isEnabled(output, key))
    }

    function shownKey(output: string, id: string): string {
        const list = root.pagesOn(output, id)
        const key = root.pages[id]?.key
        return list.indexOf(key) >= 0 ? key : (list[0] ?? "")
    }

    // What a widget needs to know about the stack it is in on this output, or null when it stands alone.
    function info(output: string, widgetKey: string): var {
        if (!root.live || root._lock(output))
            return null
        const id = root.memberMap[widgetKey]
        if (id === undefined)
            return null
        const list = root.pagesOn(output, id)
        if (list.length < 2 || list.indexOf(widgetKey) < 0)
            return null
        const stack = root.stackById(id)
        const shown = root.shownKey(output, id)
        return {
            id: id,
            index: list.indexOf(widgetKey),
            keys: list,
            count: list.length,
            shown: shown === widgetKey,
            shownIndex: list.indexOf(shown),
            dir: root.pages[id]?.dir ?? 1,
            serial: root.pages[id]?.serial ?? 0,
            rotate: stack.rotate,
            interval: stack.interval,
            sizes: root.commonSizes(id),
            size: stack.size
        }
    }

    function commonSizes(id: string): var {
        const stack = root.stackById(id)
        let common = root.sizeOrder.slice()
        if (!stack)
            return common
        for (const key of stack.members) {
            const facts = root.reported[key]
            if (facts && facts.faced)
                common = common.filter(size => facts.sizes.indexOf(size) >= 0)
        }
        return common.length > 0 ? common : [root.sizeOrder[0]]
    }

    // A loaded widget states its size classes; a stack keeps only the ones all its pages have.
    function report(widgetKey: string, sizes: var, size: string, faced: bool): void {
        const next = { sizes: Array.from(sizes ?? []), size: String(size ?? ""), faced: faced }
        const before = root.reported[widgetKey]
        if (before && before.faced === next.faced && before.size === next.size
                && JSON.stringify(before.sizes) === JSON.stringify(next.sizes))
            return
        const copy = Object.assign({}, root.reported)
        copy[widgetKey] = next
        root.reported = copy
        const stack = root.stackOf(widgetKey)
        if (stack)
            Qt.callLater(() => root._fitSize(stack.id))
    }

    function _fitSize(id: string): void {
        const stack = root.stackById(id)
        if (!stack)
            return
        const common = root.commonSizes(id)
        const fit = size => {
            if (common.indexOf(size) >= 0)
                return size
            const at = root.sizeOrder.indexOf(size)
            for (let i = at - 1; i >= 0; --i)
                if (common.indexOf(root.sizeOrder[i]) >= 0)
                    return root.sizeOrder[i]
            return common[0]
        }
        const key = root.prefix + id
        for (const record of (Config.options?.background?.widgets?.outputOverrides ?? [])) {
            const size = record?.widgets?.[key]?.["iris.size"]
            if (size !== undefined && fit(size) !== size)
                DesktopWidgetLayout.setValue(String(record.output), key, "iris.size", fit(size))
        }
        if (stack.size.length > 0 && fit(stack.size) !== stack.size)
            root._patch(id, { size: fit(stack.size) })
    }

    // ── Paging ─────────────────────────────────────────────────────────────

    function _page(id: string, key: string, dir: int): void {
        const now = Object.assign({}, root.pages)
        now[id] = { key: key, dir: dir, serial: (root.pages[id]?.serial ?? 0) + 1 }
        root.pages = now
    }

    function step(output: string, id: string, delta: int): bool {
        const list = root.pagesOn(output, id)
        if (list.length < 2)
            return false
        const from = Math.max(0, list.indexOf(root.shownKey(output, id)))
        const to = ((from + delta) % list.length + list.length) % list.length
        root._page(id, list[to], delta >= 0 ? 1 : -1)
        return true
    }

    function show(output: string, id: string, key: string): bool {
        const list = root.pagesOn(output, id)
        const to = list.indexOf(key)
        if (to < 0)
            return false
        const from = list.indexOf(root.shownKey(output, id))
        if (from !== to)
            root._page(id, key, to > from ? 1 : -1)
        return true
    }

    function setHovered(id: string, on: bool): void {
        if (Boolean(root.hovering[id]) === on)
            return
        const now = Object.assign({}, root.hovering)
        now[id] = on
        root.hovering = now
    }

    // Arranging: selecting a widget that is one of a stack's pages brings that page up.
    Connections {
        target: GlobalStates
        function onSelectedDesktopWidgetChanged(): void {
            const parts = String(GlobalStates.selectedDesktopWidget ?? "").split("::")
            if (parts.length !== 2)
                return
            const id = root.memberMap[parts[1]]
            if (id !== undefined && root.live)
                root.show(parts[0], id, parts[1])
        }
    }

    function _rotatingOutput(stack: var): string {
        if (!root.live || !stack.rotate || GlobalStates.widgetEditMode || root.hovering[stack.id])
            return ""
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; ++i) {
            const name = String(screens[i]?.name ?? "")
            // Turning pages nobody can see is a redraw for nothing.
            if (root.pagesOn(name, stack.id).length >= 2 && WidgetPowerManager.widgetsActiveForOutput(name)
                    && Wallpapers.videoMotionAllowedOn(name)
                    && !(CompositorService.isNiri && NiriService.activeWorkspaceCovers(name)))
                return name
        }
        return ""
    }

    Instantiator {
        model: root.live ? root.stacks : []
        delegate: Timer {
            id: rotation
            required property var modelData
            readonly property string output: root._rotatingOutput(rotation.modelData)
            interval: rotation.modelData.interval * 1000
            repeat: true
            running: rotation.output.length > 0
            onTriggered: root.step(rotation.output, rotation.modelData.id, 1)
            readonly property int serial: root.pages[rotation.modelData.id]?.serial ?? 0
            // A page turned by hand or by selection starts the wait again.
            onSerialChanged: if (rotation.running) rotation.restart()
        }
    }

    // ── Editing ────────────────────────────────────────────────────────────

    function _patch(id: string, fields: var): void {
        const next = []
        for (const stack of root.stacks) {
            next.push(stack.id === id ? Object.assign({}, stack, fields) : stack)
        }
        Config.setNestedValue("background.widgets.stacks", next)
    }

    function _outputs(): var {
        const names = Array.from(DesktopWidgetLayout.savedOutputNames())
        for (const screen of Quickshell.screens) {
            const name = String(screen?.name ?? "")
            if (name.length > 0 && names.indexOf(name) < 0)
                names.push(name)
        }
        return names
    }

    // What `key` shows now on `output` for every shared value, whichever record it comes from.
    function _effective(output: string, key: string): var {
        const values = ({})
        for (const valueKey of Object.keys(root.sharedKeys)) {
            const value = DesktopWidgetLayout.value(output, key, valueKey, undefined)
            if (value !== undefined)
                values[valueKey] = value
        }
        return values
    }

    function _unfaced(key: string): bool {
        const facts = root.reported[key]
        return !facts || !facts.faced
    }

    function create(keys: var): string {
        const members = []
        for (const key of Array.from(keys ?? [])) {
            const name = String(key)
            if (name.length > 0 && members.indexOf(name) < 0)
                members.push(name)
        }
        if (members.length < 2)
            return ""
        for (const name of members) {
            if (root.memberMap[name] !== undefined || root._unfaced(name))
                return ""
        }
        const id = "s" + Date.now().toString(36)
        const anchor = members[0]
        const facts = root.reported[anchor]
        for (const output of root._outputs()) {
            const values = root._effective(output, anchor)
            if (values["iris.size"] === undefined && facts?.size)
                values["iris.size"] = facts.size
            DesktopWidgetLayout.setValues(output, root.prefix + id, values)
        }
        const list = root.stacks.slice()
        list.push({ id: id, members: members, rotate: true, interval: root.defaultInterval, size: facts?.size ?? "" })
        Config.setNestedValue("background.widgets.stacks", list)
        for (const name of members)
            root._ownDesign(name)
        root._page(id, anchor, 1)
        Qt.callLater(() => root._fitSize(id))
        return id
    }

    // A stack shows its pages in the iRiS design; a widget that chose another look for itself gives it up.
    function _ownDesign(key: string): void {
        const updates = ({})
        if (Config.getNestedValue("background.widgets." + key + ".iris.design", "auto") !== "auto")
            updates["background.widgets." + key + ".iris.design"] = "auto"
        if (Object.keys(updates).length > 0)
            Config.setNestedValues(updates)
        for (const record of (Config.options?.background?.widgets?.outputOverrides ?? [])) {
            const own = record?.widgets?.[key]?.["iris.design"]
            if (own !== undefined && own !== "auto")
                DesktopWidgetLayout.setValue(String(record.output), key, "iris.design", "auto")
        }
    }

    function add(id: string, key: string): bool {
        const stack = root.stackById(id)
        const name = String(key ?? "")
        if (!stack || name.length === 0 || root.memberMap[name] !== undefined || root._unfaced(name))
            return false
        root._ownDesign(name)
        root._patch(id, { members: stack.members.concat([name]) })
        Qt.callLater(() => root._fitSize(id))
        return true
    }

    // The widget leaves standing where the stack stands, with the stack's look; the canvas moves it aside.
    function _release(id: string, key: string, aside: bool): void {
        if (aside) {
            const now = Object.assign({}, root.splits)
            now[key] = true
            root.splits = now
            splitExpiry.restart()
        }
        const stackKey = root.prefix + id
        for (const output of root._outputs()) {
            const values = ({})
            for (const valueKey of Object.keys(root.sharedKeys)) {
                const value = DesktopWidgetLayout.value(output, stackKey, valueKey, undefined)
                if (value !== undefined)
                    values[valueKey] = value
            }
            if (Object.keys(values).length > 0)
                DesktopWidgetLayout.setValues(output, key, values)
        }
    }

    Timer {
        id: splitExpiry
        interval: 4000
        onTriggered: root.clearSplits()
    }

    function isSplit(key: string): bool {
        return root.splits[key] === true
    }

    function clearSplits(): void {
        if (root.splitPending)
            root.splits = ({})
    }

    // Membership changes first, so what is written for a leaving widget lands in its own record.
    // `aside` asks the canvas to move the widget clear of the stack it left.
    function remove(key: string, aside = true): bool {
        const stack = root.stackOf(key)
        if (!stack)
            return false
        const rest = stack.members.filter(name => name !== key)
        if (rest.length < 2) {
            root._dropStack(stack.id)
            root._release(stack.id, key, aside)
            root._release(stack.id, rest[0], false)
            root._dropRecords(stack.id)
        } else {
            root._patch(stack.id, { members: rest })
            root._release(stack.id, key, aside)
            if (root.pages[stack.id]?.key === key)
                root._page(stack.id, rest[0], 1)
        }
        return true
    }

    // A widget taken off the desktop leaves its stack where it stood.
    function leave(key: string): void {
        root.remove(key, false)
    }

    // One widget dropped on another: a new stack at the target's place, or a page added to the stack it is in.
    function merge(targetKey: string, droppedKey: string): string {
        const target = root.stackOf(targetKey)
        const dropped = root.stackOf(droppedKey)
        if (target && dropped)
            return ""
        if (target)
            return root.add(target.id, droppedKey) ? target.id : ""
        if (dropped)
            return root.add(dropped.id, targetKey) ? dropped.id : ""
        return root.create([targetKey, droppedKey])
    }

    // The widgets that could join: on this desktop, wearing a face, in no stack yet.
    function candidates(output: string, key: string): var {
        void Config.revision
        return Object.keys(root.reported).filter(name => name !== key && root.reported[name].faced
            && root.memberMap[name] === undefined && root._isEnabled(output, name))
    }

    function dissolve(id: string): bool {
        const stack = root.stackById(id)
        if (!stack)
            return false
        root._dropStack(id)
        stack.members.forEach((key, index) => root._release(id, key, index > 0))
        root._dropRecords(id)
        return true
    }

    function _dropStack(id: string): void {
        Config.setNestedValue("background.widgets.stacks", root.stacks.filter(stack => stack.id !== id))
        const now = Object.assign({}, root.pages)
        delete now[id]
        root.pages = now
    }

    function _dropRecords(id: string): void {
        for (const output of root._outputs())
            DesktopWidgetLayout.clearWidget(output, root.prefix + id)
    }

    function move(id: string, key: string, delta: int): bool {
        const stack = root.stackById(id)
        if (!stack)
            return false
        const from = stack.members.indexOf(key)
        const to = from + delta
        if (from < 0 || to < 0 || to >= stack.members.length)
            return false
        const members = stack.members.slice()
        members.splice(from, 1)
        members.splice(to, 0, key)
        root._patch(id, { members: members })
        return true
    }

    function setRotate(id: string, on: bool): bool {
        if (!root.stackById(id))
            return false
        root._patch(id, { rotate: on })
        return true
    }

    function setSeconds(id: string, seconds: int): bool {
        if (!root.stackById(id))
            return false
        root._patch(id, { interval: Math.max(5, Math.min(3600, seconds)) })
        return true
    }

    function describe(): string {
        const names = Quickshell.screens.map(screen => String(screen?.name ?? ""))
        return JSON.stringify({
            live: root.live,
            stacks: root.stacks.map(stack => ({
                id: stack.id, members: stack.members, rotate: stack.rotate, interval: stack.interval,
                sizes: root.commonSizes(stack.id), size: stack.size,
                shown: names.reduce((all, name) => {
                    all[name] = root.shownKey(name, stack.id)
                    return all
                }, ({}))
            }))
        })
    }

    IpcHandler {
        target: "widgetStacks"

        function status(): string { return root.describe() }
        function create(widgets: string): string {
            const id = root.create(widgets.split("+").map(name => name.trim()).filter(name => name.length > 0))
            return id.length > 0 ? id : "needs two or more iRiS widgets on the desktop that are not in a stack"
        }
        function add(stack: string, widget: string): string {
            return root.add(stack, widget) ? "added" : "not added"
        }
        function remove(widget: string): string {
            return root.remove(widget) ? "left the stack" : "not in a stack"
        }
        function dissolve(stack: string): string {
            return root.dissolve(stack) ? "dissolved" : "no such stack"
        }
        function page(stack: string, to: string): string {
            const output = String(GlobalStates.focusedScreen?.name ?? Quickshell.screens[0]?.name ?? "")
            if (to === "next" || to === "previous")
                return root.step(output, stack, to === "next" ? 1 : -1) ? root.shownKey(output, stack) : "no such stack"
            return root.show(output, stack, to) ? to : "not a page of that stack"
        }
        function move(stack: string, widget: string, delta: int): string {
            return root.move(stack, widget, delta) ? "moved" : "not moved"
        }
        function rotate(stack: string, mode: string): string {
            return root.setRotate(stack, mode === "on") ? "rotation " + mode : "no such stack"
        }
        function interval(stack: string, seconds: int): string {
            return root.setSeconds(stack, seconds) ? seconds + " s" : "no such stack"
        }
    }
}
