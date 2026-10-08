pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

IrisButton {
    id: root
    property string glyph: ""
    readonly property real d: IrisStyle.density
    quiet: true
    implicitWidth: Math.round(34 * root.d)
    implicitHeight: implicitWidth
    buttonRadius: height / 2
    buttonRadiusPressed: height / 2
    colBackground: IrisStyle.fillQuiet
    colBackgroundHover: IrisStyle.fillHover
    MaterialSymbol {
        anchors.centerIn: parent
        text: root.glyph
        fill: 1
        iconSize: Math.round(17 * root.d)
        color: !root.enabled ? IrisStyle.muted : root.selected ? IrisStyle.accent : IrisStyle.text
    }
}
