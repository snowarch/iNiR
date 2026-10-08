pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.preview
import qs.modules.iris.preview.parts

PreviewScene {
    id: motionRoot
    readonly property real naturalWidth: Math.round(540 * motionRoot.d)
    readonly property real naturalHeight: Math.round(280 * motionRoot.d)
    IrisMotionLab {
        anchors.fill: parent
        anchors.margins: Math.round(12 * motionRoot.d)
        playing: motionRoot.playing && motionRoot.preview.visible && IrisStyle.motionEnabled
    }
    Caption { glyph: "animation"; text: IrisStyle.motionEnabled ? Translation.tr("The same motion when opening and closing") : Translation.tr("Motion is off") }
}
