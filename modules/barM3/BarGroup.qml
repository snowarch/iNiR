import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property int currentIndex: 0
    property int totalCount: 0
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    property bool paintMaterialPill: false
    property real padding: (root.isMaterial && !root.paintMaterialPill) ? 0 : 5
    property color bgColor: M3Palette.primaryContainer
    readonly property Item spectrumClipItem: background
    readonly property var spectrumClipRadii: [
        background.topLeftRadius, background.topRightRadius,
        background.bottomRightRadius, background.bottomLeftRadius
    ]

    readonly property real fullRadius: height / 2
    readonly property real midRadius: Config.options.bar.m3.cornerStyle === 2 ? Appearance.rounding.unsharpenmore + 2 : Appearance.rounding.unsharpenmore
    property real startRadius: {
        if (totalCount <= 1) return fullRadius;
        if (currentIndex === 0) return fullRadius;
        return midRadius;
    }
    property real endRadius: {
        if (totalCount <= 1) return fullRadius;
        if (currentIndex === totalCount - 1) return fullRadius;
        return midRadius;
    }

    implicitWidth: vertical && root.isMaterial ? Appearance.sizes.baseVerticalBarWidth - 6 : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight

    default property alias items: gridLayout.children

    Rectangle {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        color: !(Config.options?.bar?.m3?.showBackground ?? true)
            ? "transparent"
            : (root.isMaterial && !root.paintMaterialPill)
                ? "transparent"
                : (root.isMaterial && root.paintMaterialPill)
                    ? root.bgColor
                    : (Config.options?.bar.m3.borderless === "transparent"
                        ? "transparent"
                        : Config.options.bar.m3.cornerStyle === 2
                        ? M3Palette.surface
                        : M3Palette.surfaceContainerLow)
        border.width: root.isMaterial && root.paintMaterialPill
            && (Config.options?.bar?.m3?.borderless ?? "pills") === "separated" ? 1 : 0
        border.color: M3Palette.outlineVariant

        topLeftRadius: (root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (Config.options?.bar.m3.borderless === "separated" ? root.fullRadius : root.startRadius)
        bottomLeftRadius: (root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (Config.options?.bar.m3.borderless === "separated" ? root.fullRadius : root.vertical ? root.endRadius : root.startRadius)
        topRightRadius: (root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (Config.options?.bar.m3.borderless === "separated" ? root.fullRadius : root.vertical ? root.startRadius : root.endRadius)
        bottomRightRadius: (root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (Config.options?.bar.m3.borderless === "separated" ? root.fullRadius : root.endRadius)

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors.centerIn: parent
        columnSpacing: 0
        rowSpacing: 0
    }
}
