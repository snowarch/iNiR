import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Shared card surface for dashboard widgets. Optional icon+title header;
 * children land in the inner column. Style-dispatched like the controlPanel
 * section cards.
 */
Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    default property alias content: inner.data

    // Appearance knobs (Settings › Dashboard › Appearance)
    readonly property bool compact: (Config.options?.dashboard?.appearance?.density ?? "comfortable") === "compact"
    readonly property real cardOpacity: Math.max(0.3, Math.min(1, Config.options?.dashboard?.appearance?.cardOpacity ?? 1))
    readonly property bool showTitle: Config.options?.dashboard?.appearance?.showCardTitles ?? true
    readonly property real pad: compact ? 8 : 12

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool zzzEverywhere: Appearance.zzzEverywhere
    readonly property color colText: zzzEverywhere ? Appearance.zzz.ink
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : inirEverywhere ? Appearance.inir.colText
        : auroraEverywhere ? Appearance.colors.colOnSurface
        : Appearance.colors.colOnLayer1
    readonly property color colSubtext: zzzEverywhere ? Appearance.zzz.inkMuted
        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color colAccent: zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : inirEverywhere ? Appearance.inir.colPrimary
        : auroraEverywhere ? Appearance.colors.colPrimary
        : Appearance.colors.colPrimary

    Layout.fillWidth: true
    implicitHeight: contentColumn.implicitHeight + root.pad * 2

    radius: zzzEverywhere ? Appearance.zzz.panelRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: {
        const base = zzzEverywhere ? Appearance.zzz.paper
            : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : inirEverywhere ? Appearance.inir.colLayer1
            : auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colLayer1
        return zzzEverywhere || root.cardOpacity >= 1 ? base : ColorUtils.applyAlpha(base, root.cardOpacity * base.a)
    }
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }
    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    border.width: Appearance.angelEverywhere ? 0
        : zzzEverywhere ? 0 : 1
    border.color: Appearance.angelEverywhere ? "transparent"
        : zzzEverywhere ? Appearance.zzz.hairline
        : inirEverywhere ? Appearance.inir.colBorder
        : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    AngelPartialBorder { targetRadius: root.radius; coverage: 0.45 }

    // Glassy top-edge highlight: a faint light sheen down the upper third reads
    // as a translucent pane catching light. Pure overlay, no blur FBO — zero
    // GPU cost beyond one clipped gradient. Skipped for angel (own glass system).
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: !Appearance.angelEverywhere && !root.zzzEverywhere
        z: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.05) }
            GradientStop { position: 0.35; color: "transparent" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Clean ZZZ plate: surface + a single left category accent bar. No per-card
    // ghost/tape/hatch — the bold ZZZ statement lives at panel level.
    ZzzGraphicPlate {
        anchors.fill: parent
        accentColor: root.colAccent
        frameLabel: ""
        frameIndex: ""
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.compact ? 6 : 8

        RowLayout {
            visible: root.title.length > 0 && root.showTitle
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                visible: root.icon.length > 0 && !root.zzzEverywhere
                text: root.icon
                iconSize: Appearance.font.pixelSize.larger
                color: root.colAccent
            }
            ZzzGlyphBadge {
                visible: root.icon.length > 0 && root.zzzEverywhere
                symbol: root.icon
                accentColor: root.colAccent
                inkColor: Appearance.zzz.onAccent
                badgeSize: 26
            }
            StyledText {
                Layout.fillWidth: true
                text: root.zzzEverywhere ? root.title.toUpperCase() : root.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: root.zzzEverywhere ? Font.Black : Font.Medium
                color: root.colText
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            id: inner
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Center every card's content by default. A child that explicitly
            // fills width (lists, meters, calendars, full-bleed widgets) keeps
            // doing so and owns its own internal alignment; a child that doesn't
            // fill gets centered instead of hugging the left edge.
            Component.onCompleted: {
                for (let i = 0; i < inner.children.length; i++) {
                    const c = inner.children[i]
                    if (c.Layout && c.Layout.fillWidth !== true && c.Layout.fillHeight !== true && c.Layout.alignment === 0)
                        c.Layout.alignment = Qt.AlignHCenter | Qt.AlignVCenter
                }
            }
        }
    }
}
