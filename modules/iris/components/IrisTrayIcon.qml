pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.iris.style

// A tray icon. Monochrome glyphs are drawn white for a dark bar; on a light surface they turn to ink, the way a
// template image does, and coloured icons stay as they are.
IconImage {
    id: root

    readonly property bool template: /mono|symbolic|panel|-light|_light|white/i.test(String(root.source))

    layer.enabled: IrisStyle.light && root.template
    layer.effect: MultiEffect { brightness: -1 }
}
