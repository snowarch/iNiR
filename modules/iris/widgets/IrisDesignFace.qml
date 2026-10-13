import QtQuick
import qs.modules.iris.style

// The face of a widget iRiS does not draw itself (the visualizer, the editorial, Japanese type): it exists only where
// the active Design prints that widget (`part`), and is nothing but that print, fed by the widget it stands for.
IrisWidgetFace {
    id: root
    property string part: ""
    designFace: IrisDesign.skin(root.part)
}
