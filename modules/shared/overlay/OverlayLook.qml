pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
Singleton {
    id: root

    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"

    readonly property color colOnLayer0: root.iris ? FamilyStyle.text : Appearance.colors.colOnLayer0
    readonly property color colOnLayer1: root.iris ? FamilyStyle.text : Appearance.colors.colOnLayer1
    readonly property color colOnLayer2: root.iris ? FamilyStyle.text : Appearance.colors.colOnLayer2
    readonly property color colOnLayer3: root.iris ? FamilyStyle.text : Appearance.colors.colOnLayer3
    readonly property color colOnSurface: root.iris ? FamilyStyle.text : Appearance.colors.colOnSurface
    readonly property color colSubtext: root.iris ? FamilyStyle.textSecondary : Appearance.colors.colSubtext

    readonly property color colLayer0: root.iris ? FamilyStyle.bodySurface : Appearance.colors.colLayer0
    readonly property color colSurfaceContainer: root.iris ? FamilyStyle.bodySurface : Appearance.colors.colSurfaceContainer
    readonly property color colLayer1Hover: root.iris ? FamilyStyle.fillHover : Appearance.colors.colLayer1Hover
    readonly property color colLayer2: root.iris ? FamilyStyle.fill : Appearance.colors.colLayer2
    readonly property color colLayer2Hover: root.iris ? FamilyStyle.fillHover : Appearance.colors.colLayer2Hover
    readonly property color colLayer2Active: root.iris ? FamilyStyle.fillActive : Appearance.colors.colLayer2Active
    readonly property color colLayer3: root.iris ? FamilyStyle.fill : Appearance.colors.colLayer3
    readonly property color colLayer3Hover: root.iris ? FamilyStyle.fillHover : Appearance.colors.colLayer3Hover
    readonly property color colLayer3Active: root.iris ? FamilyStyle.fillActive : Appearance.colors.colLayer3Active

    readonly property color colPrimary: root.iris ? FamilyStyle.accent : Appearance.colors.colPrimary
    readonly property color colPrimaryContainer: root.iris ? FamilyStyle.tintFill(FamilyStyle.accent) : Appearance.colors.colPrimaryContainer
    readonly property color colPrimaryContainerHover: root.iris ? FamilyStyle.tintFillHover(FamilyStyle.accent) : Appearance.colors.colPrimaryContainerHover
    readonly property color colPrimaryContainerActive: root.iris ? FamilyStyle.tintFillHover(FamilyStyle.accent) : Appearance.colors.colPrimaryContainerActive
    readonly property color colOnPrimaryContainer: root.iris ? FamilyStyle.accent : Appearance.colors.colOnPrimaryContainer
    readonly property color colSecondaryContainer: root.iris ? FamilyStyle.fill : Appearance.colors.colSecondaryContainer
    readonly property color colRecessed: root.iris ? FamilyStyle.fillQuiet : Appearance.colors.colSecondaryContainer

    readonly property color colError: root.iris ? FamilyStyle.danger : Appearance.colors.colError
    readonly property color colErrorActive: root.iris ? FamilyStyle.tintFillHover(FamilyStyle.danger) : Appearance.colors.colErrorActive
    readonly property color colErrorContainer: root.iris ? FamilyStyle.tintFill(FamilyStyle.danger) : Appearance.colors.colErrorContainer
    readonly property color colOnErrorContainer: root.iris ? FamilyStyle.danger : Appearance.colors.colOnErrorContainer

    readonly property real roundingSmall: root.iris ? FamilyStyle.radiusRow : Appearance.rounding.small
    readonly property real roundingNormal: root.iris ? FamilyStyle.radiusTile : Appearance.rounding.normal
    readonly property string fontNumbers: root.iris ? FamilyStyle.fontNumbers : Appearance.font.family.numbers

    readonly property var titles: ({
        crosshair: "Crosshair", fpsLimiter: "FPS limiter", floatingImage: "Floating image", recorder: "Recorder",
        resources: "Resources", gamePerformance: "Game Performance", notes: "Notes", discord: "Discord", volumeMixer: "Volume mixer", notifications: "Notifications"
    })
}
