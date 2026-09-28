pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions

// The desktop menu, one model for the widget canvas and the bare background: the wallpaper as its
// head, then the actions chosen in Settings (`iris.desktopMenu.items`), grouped by what they touch,
// with a line between groups.
Singleton {
    id: root

    function inir(args: var): void {
        Quickshell.execDetached([Quickshell.shellPath("scripts/inir")].concat(args))
    }

    // Every action the menu can carry. `group` orders the sections: the desktop, tools, the shell.
    readonly property var catalogue: [
        { id: "widgets", group: 0, label: Translation.tr("Edit widgets"), glyph: "widgets", tint: "teal",
            run: screen => {
                Config.setNestedValue("iris.modules.desktopWidgets", true)
                GlobalStates.setWidgetEditMode(true)
            } },
        { id: "addWidgets", group: 0, label: Translation.tr("Add widgets"), glyph: "add_circle", tint: "teal",
            run: screen => {
                Config.setNestedValue("iris.modules.desktopWidgets", true)
                GlobalStates.setWidgetEditMode(true)
                GlobalStates.desktopWidgetManagerToggleRequested(screen)
            } },
        { id: "customize", group: 0, label: Translation.tr("Customize iRiS"), glyph: "palette", tint: "purple",
            run: screen => { GlobalStates.irisEdit = true } },
        { id: "nextWallpaper", group: 0, label: Translation.tr("Next wallpaper"), glyph: "shuffle", tint: "pink",
            run: screen => Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode, screen) },
        { id: "screenshot", group: 1, label: Translation.tr("Screenshot"), glyph: "screenshot_region", tint: "blue",
            run: screen => root.inir(["region", "screenshot"]) },
        { id: "record", group: 1, label: Translation.tr("Record screen"), glyph: "screen_record", tint: "red",
            run: screen => root.inir(["region", "record"]) },
        { id: "colorPicker", group: 1, label: Translation.tr("Pick a colour"), glyph: "colorize", tint: "orange",
            run: screen => root.inir(["colorpicker"]) },
        { id: "terminal", group: 1, label: Translation.tr("Terminal"), glyph: "terminal", tint: "gray",
            run: screen => root.inir(["terminal"]) },
        { id: "files", group: 1, label: Translation.tr("Files"), glyph: "folder", tint: "sky",
            run: screen => Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") ?? "/"]) },
        { id: "settings", group: 2, label: Translation.tr("Settings"), glyph: "settings", tint: "gray",
            run: screen => root.inir(["iris", "settings", ""]) },
        { id: "restart", group: 2, label: Translation.tr("Restart shell"), glyph: "restart_alt", tint: "gray",
            run: screen => root.inir(["restart"]) }
    ]
    readonly property var defaultItems: ["widgets", "customize", "screenshot", "terminal", "settings", "restart"]

    readonly property var options: Config.options?.iris?.desktopMenu ?? ({})
    readonly property bool showWallpaper: root.options.wallpaper ?? true
    readonly property var chosen: {
        const list = Array.from(root.options.items ?? root.defaultItems)
        return list.filter(id => root.catalogue.some(entry => entry.id === id))
    }

    function menu(screenName: string, wallpaper: string, preview: string): var {
        const out = []
        if (root.showWallpaper)
            out.push({ type: "hero", text: Translation.tr("Wallpaper"), detail: Translation.tr("Change"), image: preview,
                iconName: "chevron_right",
                action: () => {
                    GlobalStates.wallpaperSelectorTargetMonitor = screenName
                    GlobalActions.runLauncher(["wallpaperSelector", "toggle"])
                },
                secondary: { iconName: "shuffle", text: Translation.tr("Next wallpaper"),
                    action: () => Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode, screenName) } })
        const groupOf = id => root.catalogue.find(item => item.id === id).group
        const ordered = root.chosen.map((id, index) => ({ id: id, index: index }))
            .sort((a, b) => groupOf(a.id) - groupOf(b.id) || a.index - b.index).map(item => item.id)
        let group = -1
        for (const id of ordered) {
            const entry = root.catalogue.find(item => item.id === id)
            if (group >= 0 ? entry.group !== group : out.length > 0)
                out.push({ type: "separator" })
            group = entry.group
            out.push({ text: entry.label, iconName: entry.glyph, tint: entry.tint, action: () => entry.run(screenName) })
        }
        return out
    }
}
