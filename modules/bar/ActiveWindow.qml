import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
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

    // Terminal spinners and browser progress titles can change many times per
    // second. Keep the app identity reactive, but only repaint the title after
    // a short quiet period so those updates do not continuously dirty the bar.
    property string stableDisplayTitle: displayTitle
    Component.onCompleted: stableDisplayTitle = displayTitle
    onDisplayTitleChanged: titleSettleTimer.restart()
    Timer {
        id: titleSettleTimer
        interval: 180
        repeat: false
        onTriggered: root.stableDisplayTitle = root.displayTitle
    }

    // Intentionally NOT binding implicitWidth to colLayout.implicitWidth:
    // the bar wrapper assigns this item its width via Layout.fillWidth, and the
    // texts elide to fit. Binding to content width would let a long title push
    // the whole bar around on every title change.
    implicitWidth: 0
    clip: true
    // Natural content width, exposed so a content-sized host (e.g. a centre
    // pill, which gives no fill slack) can grant a sensible, clamped width.
    readonly property real contentImplicitWidth: Math.max(
        appNameText.implicitWidth,
        titleText.visible ? titleText.implicitWidth : 0
    )

    readonly property bool showTitle: Config.options?.bar?.activeWindow?.showTitle ?? true

    property color titleColor: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
    property color appNameColor: Appearance.regaliaEverywhere ? Appearance.regalia.onMuted
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext

    // Lock both rows to baselines derived from the configured UI font. Emoji,
    // Nerd Font symbols and other fallback glyphs may report taller bounds, but
    // they can no longer move either row or change the gap between them.
    readonly property real rowOverlap: root.showTitle ? 2 : 0
    readonly property real textBlockHeight: root.showTitle
        ? appNameMetrics.height + titleMetrics.height - root.rowOverlap
        : appNameMetrics.height
    readonly property real textBlockTop: Math.round((root.height - root.textBlockHeight) / 2)
    readonly property real appNameBaseline: root.textBlockTop + appNameMetrics.ascent
    readonly property real titleBaseline: root.appNameBaseline
        + appNameMetrics.descent
        - root.rowOverlap
        + titleMetrics.ascent

    FontMetrics {
        id: appNameMetrics
        font: appNameText.font
    }

    FontMetrics {
        id: titleMetrics
        font: titleText.font
    }

    StyledText {
        id: appNameText
        width: root.width
        y: root.appNameBaseline - baselineOffset
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: root.appNameColor
        elide: Text.ElideRight
        text: root.displayAppName
    }

    StyledText {
        id: titleText
        width: root.width
        y: root.titleBaseline - baselineOffset
        visible: root.showTitle
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        font.pixelSize: Appearance.font.pixelSize.small
        color: root.titleColor
        elide: Text.ElideRight
        text: root.stableDisplayTitle
    }

}
