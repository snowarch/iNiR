pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.components
import qs.modules.iris.style

IrisSegmented {
    id: root
    required property var picker
    readonly property bool wanted: (root.picker?.kindsPresent ?? []).length > 2

    glyphOnly: true
    implicitHeight: Math.round(34 * IrisStyle.density)
    accessibleName: "Kind"
    options: (root.picker?.kindsPresent ?? []).map(entry => ({ value: entry.id, label: entry.label, glyph: entry.glyph }))
    current: String(root.picker?.kind ?? "all")
    onPicked: value => root.picker.kind = value
}
