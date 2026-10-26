import QtQuick
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.widgets

// What iRiS hands the base as its part `style` (modules/common/FamilyStyle.qml): its tokens for shared surfaces, the
// room its frame takes at each edge, and which desktop widgets the worn Design prints its own face for.
QtObject {
    readonly property QtObject style: IrisStyle
    readonly property var prints: IrisFaceData.prints
    function frameInset(edge: string): real { return IrisFrame.inset(edge) }
}
