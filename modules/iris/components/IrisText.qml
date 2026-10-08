import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style

StyledText {
    id: root

    enum Role { Body, Meta, Eyebrow, Title, Display, Metric }
    property int role: IrisText.Body

    color: role === IrisText.Meta || role === IrisText.Eyebrow ? IrisStyle.subtext : IrisStyle.text
    defaultFont: (role === IrisText.Title || role === IrisText.Display)
        ? IrisStyle.fontTitle
        : role === IrisText.Metric ? IrisStyle.fontNumbers
        : IrisStyle.fontMain
    font.family: defaultFont
    font.pixelSize: role === IrisText.Meta ? IrisStyle.typeMeta
        : role === IrisText.Eyebrow ? IrisStyle.typeFootnote
        : role === IrisText.Title ? IrisStyle.typeTitle
        : role === IrisText.Display ? IrisStyle.typeDisplay
        : role === IrisText.Metric ? IrisStyle.typeTitleLarge : IrisStyle.typeBody
    font.weight: IrisStyle.weight(role === IrisText.Meta ? Font.Normal
        : role === IrisText.Eyebrow ? Font.DemiBold
        : role === IrisText.Title ? Font.DemiBold
        : role === IrisText.Display || role === IrisText.Metric ? Font.Bold : Font.Medium)
    font.letterSpacing: role === IrisText.Display ? IrisStyle.tracking(IrisStyle.typeDisplay)
        : role === IrisText.Metric ? IrisStyle.tracking(IrisStyle.typeTitleLarge) : 0
    font.variableAxes: ({})
    // Whole-pixel size: a text's fractional natural size puts every neighbour after it off the pixel grid.
    width: Math.ceil(implicitWidth)
    height: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : root.implicitHeight
    Layout.preferredWidth: Math.ceil(implicitWidth)
    Layout.preferredHeight: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : -1
    transform: Translate { x: Math.round(root.x) - root.x; y: Math.round(root.y) - root.y }
}
