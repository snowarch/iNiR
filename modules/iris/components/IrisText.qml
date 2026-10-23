import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style

StyledText {
    id: root

    // Roles, not sizes, in the three Signal voices (DESIGN.md S2):
    //   Read   Body, Meta, Name, Detail, Title, Display: Geist, sentence case, hierarchy by size then weight then ink.
    //   Label  Eyebrow, Group, Value, Label: Geist Mono caps, tracked +0.08 em, quiet ink, three words at most.
    //   Dot    Metric, Dot: Geist Pixel Circle, a figure of 22 px or more and nothing else.
    enum Role { Body, Meta, Eyebrow, Title, Display, Metric, Name, Value, Detail, Group, Label, Dot }
    property int role: IrisText.Body
    // A Value's ink. Quiet by default: a value is read after its name, it does not shout. Signal only when it needs you.
    property color tone: IrisStyle.subtext

    readonly property bool labelRole: role === IrisText.Eyebrow || role === IrisText.Group || role === IrisText.Value
        || role === IrisText.Label
    readonly property bool dotRole: role === IrisText.Metric || role === IrisText.Dot
    // Mono caps and the Dot face are Nothing's; under Apple a label reads in Geist and a figure in bold tabular.
    readonly property bool nothing: (root.labelRole || root.dotRole) && IrisStyle.wearsNothing(root)
    readonly property bool labelVoice: root.labelRole && root.nothing
    readonly property bool dotVoice: root.dotRole && root.nothing
    readonly property int voiceSize: role === IrisText.Meta || role === IrisText.Detail ? IrisStyle.typeMeta
        : role === IrisText.Name || role === IrisText.Body ? IrisStyle.typeBody
        : role === IrisText.Group ? IrisStyle.typeCaption
        : root.labelVoice ? IrisStyle.typeLabelMono
        : root.labelRole ? IrisStyle.typeMeta
        : role === IrisText.Title ? IrisStyle.typeTitle
        : role === IrisText.Display ? IrisStyle.typeTitleL
        : role === IrisText.Dot ? IrisStyle.typeDotM
        : role === IrisText.Metric ? IrisStyle.typeDotS : IrisStyle.typeBody

    color: role === IrisText.Meta || role === IrisText.Detail || role === IrisText.Eyebrow || role === IrisText.Label ? IrisStyle.subtext
        : role === IrisText.Group ? IrisStyle.textTertiary
        : role === IrisText.Value ? root.tone : IrisStyle.text
    defaultFont: root.labelVoice ? IrisStyle.fontLabel
        : root.dotVoice ? IrisStyle.fontDot
        : root.dotRole ? IrisStyle.fontNumbers
        : role === IrisText.Title || role === IrisText.Display ? IrisStyle.fontTitle
        : IrisStyle.fontRead
    font.family: defaultFont
    font.pixelSize: root.voiceSize
    font.weight: root.dotVoice ? Font.Normal
        : root.labelVoice || root.labelRole ? IrisStyle.weight(Font.Medium)
        : root.dotRole ? IrisStyle.figureWeight
        : IrisStyle.weight(role === IrisText.Title || role === IrisText.Display ? Font.DemiBold
            : role === IrisText.Name ? Font.Medium : Font.Normal)
    font.capitalization: root.labelVoice ? Font.AllUppercase : Font.MixedCase
    // Figures in a column want one width each.
    font.features: role === IrisText.Value || root.dotRole ? ({ "tnum": 1 }) : ({})
    font.letterSpacing: root.labelVoice ? IrisStyle.labelTracking(root.voiceSize)
        : root.dotVoice ? IrisStyle.dotTracking(root.voiceSize)
        : IrisStyle.tracking(root.voiceSize)
    font.variableAxes: ({})
    // Whole-pixel size: a text's fractional natural size puts every neighbour after it off the pixel grid.
    width: Math.ceil(implicitWidth)
    height: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : root.implicitHeight
    Layout.preferredWidth: Math.ceil(implicitWidth)
    Layout.preferredHeight: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : -1
    transform: Translate { x: Math.round(root.x) - root.x; y: Math.round(root.y) - root.y }
}
