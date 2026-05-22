import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    readonly property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(root.QsWindow.window?.screen) : null
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    property string activeWindowAddress: CompositorService.isHyprland ? `0x${activeWindow?.HyprlandToplevel?.address}` : ""
    property bool focusingThisMonitor: CompositorService.isHyprland ? (HyprlandData.activeWorkspace?.monitor == monitor?.name) : true
    property var biggestWindow: CompositorService.isHyprland ? HyprlandData.biggestWindowForWorkspace(HyprlandData.monitors[root.monitor?.id]?.activeWorkspace.id) : null

    // Ventana activa según Niri (focus global)
    property var niriFocusedWindow: {
        if (!CompositorService.isNiri || !NiriService || !NiriService.windows)
            return null
        const wins = NiriService.windows
        for (var i = 0; i < wins.length; ++i) {
            const w = wins[i]
            if (w && w.is_focused)
                return w
        }
        return null
    }

    function shortenText(str, maxLen) {
        if (!str)
            return ""
        const s = str.toString()
        if (s.length <= maxLen)
            return s
        return s.slice(0, maxLen - 3) + "..."
    }

    property string displayAppName: {
        if (CompositorService.isNiri) {
            const w = niriFocusedWindow
            if (w) {
                const base = w.app_id || w.appId || Translation.tr("Desktop")
                return shortenText(base, 40)
            }
            return Translation.tr("Desktop")
        }

        if (root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow) {
            return shortenText(root.activeWindow?.appId || "", 40)
        }

        const fallback = (root.biggestWindow?.class) ?? Translation.tr("Desktop")
        return shortenText(fallback, 40)
    }

    property string displayTitle: {
        if (CompositorService.isNiri) {
            const w = niriFocusedWindow
            if (w && w.title) {
                return shortenText(w.title, 80)
            }
            const wsNum = NiriService.getCurrentWorkspaceNumber()
            return shortenText(`${Translation.tr("Workspace")} ${wsNum}`, 80)
        }

        if (root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow) {
            return shortenText(root.activeWindow?.title || "", 80)
        }

        const fbTitle = (root.biggestWindow?.title) ?? `${Translation.tr("Workspace")} ${monitor?.activeWorkspace?.id ?? 1}`
        return shortenText(fbTitle, 80)
    }

    implicitWidth: colLayout.implicitWidth

    ColumnLayout {
        id: colLayout

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: -1

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.displayAppName

        }

        StyledText {
            Layout.fillWidth: true
            visible: Config.options?.bar?.activeWindow?.showTitle ?? true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            text: root.displayTitle
        }

    }

}
