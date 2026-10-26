import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.waffle.looks

// What Waffle hands the base as its part `style` (modules/common/FamilyStyle.qml): no tokens (shared surfaces keep
// Material's), only the room its taskbar takes on a screen.
QtObject {
    function insets(screen: var): var {
        const insets = ({ left: 0, top: 0, right: 0, bottom: 0 })
        const bar = Config.options?.waffles?.bar
        const outputs = bar?.screenList ?? []
        const name = screen?.name ?? ""
        const listed = !Array.isArray(outputs) || outputs.length === 0 || outputs.includes(name)
            || !outputs.some(output => Quickshell.screens.some(s => s?.name === output))
        if ((Config.options?.enabledPanels ?? []).includes("wBar") && (GlobalStates.barOpen ?? true) && listed)
            insets[(bar?.bottom ?? true) ? "bottom" : "top"] = Looks.scaledBar(48, screen)
        return insets
    }
}
