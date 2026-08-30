import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property bool vertical: false
    property string dockPosition: "bottom"
    property string surfaceDialect: Appearance.surfaceDialectFor("")
    readonly property bool zzzStyle: surfaceDialect === "zzz"
    readonly property bool regaliaStyle: surfaceDialect === "regalia"
    readonly property bool angelStyle: surfaceDialect === "angel"
    readonly property bool inirStyle: surfaceDialect === "inir"
    readonly property bool auroraStyle: surfaceDialect === "aurora" || angelStyle

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    implicitWidth: vertical ? (implicitHeight - topInset - bottomInset) : (implicitHeight - topInset - bottomInset)
    implicitHeight: 50
    // Square by construction, so the face stays organic. The dock paints no
    // resting background, which leaves the hover state as the cookie face —
    // and the pill/macOS styles hide `background` outright, so they are unaffected.
    cookieMorphing: true
    buttonRadius: root.regaliaStyle ? Appearance.regalia.roundNormal
        : root.zzzStyle ? Appearance.zzz.controlRadius
        : root.angelStyle ? Appearance.angel.roundingSmall
        : root.inirStyle ? Appearance.inir.roundingSmall : Appearance.rounding.normal

    colBackground: "transparent"

    colBackgroundHover: root.regaliaStyle ? Appearance.regalia.hoverPlate
        : root.zzzStyle ? "transparent"
        : root.angelStyle ? Appearance.angel.colGlassCard
        : root.inirStyle ? Appearance.inir.colLayer1Hover
        : root.auroraStyle ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0Hover
    colRipple: root.regaliaStyle ? Appearance.regalia.pressPlate
        : root.zzzStyle ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.22)
        : root.angelStyle ? Appearance.angel.colGlassCardActive
        : root.inirStyle ? Appearance.inir.colLayer1Active
        : root.auroraStyle ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer0Active

    background.implicitHeight: 50
    background.implicitWidth: 50

    // Single zzz tile for every dock button. Subclasses tune it through these
    // properties instead of stacking a second ZzzPlate on top — two plates over
    // the same rect draw two strokes with different corner geometry, which read
    // as a doubled border on hover.
    // Dock tiles are small: controlRadius in round mode (a clean rounded chip),
    // NOT the big panelRadius (ZzzPlate's default) which over-rounds into a blob.
    property bool zzzPlateVisible: root.zzzStyle
    property real zzzPlateRadius: Appearance.zzz.round ? Appearance.zzz.controlRadius : 0
    property real zzzPlateChamfer: Appearance.zzz.cutCorner * (root.buttonHovered ? 0.85 : 0.45)
    property color zzzPlateFill: root.buttonHovered ? ColorUtils.applyAlpha(Appearance.zzz.paper, 0.14) : "transparent"
    property color zzzPlateStroke: root.buttonHovered ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.55) : "transparent"

    ZzzPlate {
        anchors.fill: parent
        visible: root.zzzPlateVisible
        radius: root.zzzPlateRadius
        chamfer: root.zzzPlateChamfer
        fillColor: root.zzzPlateFill
        strokeColor: root.zzzPlateStroke
        strokeWidth: Appearance.zzz.borderThick
        z: -1
    }
}
