import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style

StyledText {
    id: root

    // Roles, not sizes (DI49i, 2026-10-21): a row's name, the value it holds, what it explains and the title of its group
    // read as four voices, so a page is scanned by what each line is, not read line by line in one grey.
    //   Name    what a row or an area is called: text, Medium.
    //   Value   what it is set to now: the figures face, tabular, a step heavier, in `tone` (the area's colour).
    //   Detail  what it explains: smaller, regular, quiet.
    //   Group   the title over a group: the title face, capitals, tracked out, quiet; a Design's mono voice when it has one.
    enum Role { Body, Meta, Eyebrow, Title, Display, Metric, Name, Value, Detail, Group }
    property int role: IrisText.Body
    // The colour a Value speaks in: the area's own, so the answers on a page read as one family of marks.
    property color tone: IrisStyle.accent

    color: role === IrisText.Meta || role === IrisText.Eyebrow ? IrisStyle.subtext
        : role === IrisText.Detail ? IrisStyle.muted
        : role === IrisText.Group ? IrisStyle.textTertiary
        : role === IrisText.Value ? root.tone : IrisStyle.text
    defaultFont: (role === IrisText.Title || role === IrisText.Display)
        ? IrisStyle.fontTitle
        : role === IrisText.Group ? (IrisStyle.monoCaptions ? IrisStyle.fontMono : IrisStyle.fontTitle)
        : role === IrisText.Metric || role === IrisText.Value ? IrisStyle.fontNumbers
        : IrisStyle.fontMain
    font.family: defaultFont
    font.pixelSize: role === IrisText.Meta || role === IrisText.Detail ? IrisStyle.typeMeta
        : role === IrisText.Name || role === IrisText.Value ? IrisStyle.typeLabel
        : role === IrisText.Group ? IrisStyle.typeCaption
        : role === IrisText.Eyebrow ? IrisStyle.typeFootnote
        : role === IrisText.Title ? IrisStyle.typeTitle
        : role === IrisText.Display ? IrisStyle.typeDisplay
        : role === IrisText.Metric ? IrisStyle.typeTitleLarge : IrisStyle.typeBody
    font.weight: IrisStyle.weight(role === IrisText.Meta || role === IrisText.Detail ? Font.Normal
        : role === IrisText.Group ? Font.Bold
        : role === IrisText.Value ? Font.DemiBold
        : role === IrisText.Eyebrow ? Font.DemiBold
        : role === IrisText.Title ? Font.DemiBold
        : role === IrisText.Display || role === IrisText.Metric ? Font.Bold : Font.Medium)
    font.capitalization: role === IrisText.Group ? Font.AllUppercase : Font.MixedCase
    // Capitals want air between them; figures in a column want one width each.
    font.features: role === IrisText.Value || role === IrisText.Metric ? ({ "tnum": 1 }) : ({})
    font.letterSpacing: role === IrisText.Group ? Math.max(1, Math.round(IrisStyle.typeCaption * 0.12))
        : role === IrisText.Display ? IrisStyle.tracking(IrisStyle.typeDisplay)
        : role === IrisText.Metric ? IrisStyle.tracking(IrisStyle.typeTitleLarge) : 0
    font.variableAxes: ({})
    // Whole-pixel size: a text's fractional natural size puts every neighbour after it off the pixel grid.
    width: Math.ceil(implicitWidth)
    height: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : root.implicitHeight
    Layout.preferredWidth: Math.ceil(implicitWidth)
    Layout.preferredHeight: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : -1
    transform: Translate { x: Math.round(root.x) - root.x; y: Math.round(root.y) - root.y }
}
