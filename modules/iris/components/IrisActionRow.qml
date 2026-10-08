pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.iris.style

GridLayout {
    id: root
    property real spacing: Math.round(6 * IrisStyle.density)
    readonly property var shownItems: {
        const out = []
        for (let i = 0; i < root.children.length; i++)
            if (root.children[i].visible) out.push(root.children[i])
        return out
    }
    readonly property real neededWidth: {
        let sum = 0
        for (const item of root.shownItems) sum += item.implicitWidth
        return sum + root.spacing * Math.max(0, root.shownItems.length - 1)
    }
    columns: root.width <= 0 || root.neededWidth <= root.width + 0.5 ? Math.max(1, root.shownItems.length) : 1
    columnSpacing: root.spacing
    rowSpacing: root.spacing
}
