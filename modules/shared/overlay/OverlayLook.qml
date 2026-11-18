pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions

// The bench's tokens: the active family's own when it hands a style over (FamilyStyle.p), Material's layers otherwise.
Singleton {
    id: root

    readonly property bool own: FamilyStyle.p !== null
    readonly property real d: root.own ? FamilyStyle.density : 1
    readonly property var _c: Appearance.colors

    readonly property color colOnLayer1: root.own ? FamilyStyle.text : root._c.colOnLayer1
    readonly property color colSubtext: root.own ? FamilyStyle.textSecondary : root._c.colSubtext
    readonly property color colFaint: root.own ? FamilyStyle.textTertiary : ColorUtils.applyAlpha(root._c.colSubtext, 0.7)

    readonly property color colLayer2: root.own ? FamilyStyle.fill : root._c.colLayer2
    readonly property color colLayer2Hover: root.own ? FamilyStyle.fillHover : root._c.colLayer2Hover
    readonly property color colLayer2Active: root.own ? FamilyStyle.fillActive : root._c.colLayer2Active
    // A quiet well inside a tool: a figure's track, a list's ground.
    readonly property color colRecessed: root.own ? FamilyStyle.fillQuiet : ColorUtils.applyAlpha(root._c.colOnLayer1, 0.06)
    readonly property color colHairline: root.own ? FamilyStyle.border : root._c.colOutlineVariant

    readonly property color colPrimary: root.own ? FamilyStyle.accent : root._c.colPrimary
    readonly property color colOnPrimary: root.own ? FamilyStyle.inkOnAccent : root._c.colOnPrimary
    // Something switched on (an open tool, a pinned one, a chosen value).
    readonly property color colToggle: root.own ? FamilyStyle.tintFill(FamilyStyle.accent) : root._c.colSecondaryContainer
    readonly property color colToggleHover: root.own ? FamilyStyle.tintFillHover(FamilyStyle.accent) : root._c.colSecondaryContainerHover
    readonly property color colOnToggle: root.own ? FamilyStyle.accent : root._c.colOnSecondaryContainer

    readonly property color colError: root.own ? FamilyStyle.danger : root._c.colError
    readonly property color colOnError: root.own ? FamilyStyle.onTintFor(FamilyStyle.danger) : root._c.colOnError
    readonly property color colErrorContainer: root.own ? FamilyStyle.tintFill(FamilyStyle.danger) : root._c.colErrorContainer
    readonly property color colOnErrorContainer: root.own ? FamilyStyle.danger : root._c.colOnErrorContainer
    readonly property color colSuccess: FamilyStyle.success

    readonly property real roundingSmall: root.own ? FamilyStyle.radiusRow : Appearance.rounding.small
    readonly property real roundingNormal: root.own ? FamilyStyle.radiusTile : Appearance.rounding.normal
    // A tool's plate and the strip: the family's sheet, or Material's window corner in each global style.
    readonly property real plateRadius: root.own ? FamilyStyle.radiusSheet
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.windowRounding
    readonly property string fontMain: FamilyStyle.fontMain
    readonly property string fontNumbers: root.own ? FamilyStyle.fontNumbers : Appearance.font.family.numbers

    // Type ladder of the bench.
    readonly property int typeFootnote: FamilyStyle.typeFootnote
    readonly property int typeMeta: FamilyStyle.typeMeta
    readonly property int typeBody: root.own ? Math.round(13 * FamilyStyle.typeScale) : Appearance.font.pixelSize.smallie
    readonly property int typeLabel: FamilyStyle.typeLabel
    readonly property int typeFigure: Math.round(28 * FamilyStyle.typeScale)

    // Motion: the bench's own durations (Settings › Overlay), through the family's speed.
    readonly property int openDuration: FamilyStyle.duration(Config.options?.overlay?.animationDurationMs ?? 180)
    readonly property int closeDuration: Math.round(root.openDuration * 0.8)
    readonly property int scrimDuration: FamilyStyle.duration(Config.options?.overlay?.scrimAnimationDurationMs ?? 140)
    readonly property bool zoom: Config.options?.overlay?.openingZoomAnimation ?? true
}
