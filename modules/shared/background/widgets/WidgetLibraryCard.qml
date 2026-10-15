pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style

Rectangle {
    id: root

    required property string widgetKey
    required property string title
    required property string symbol
    property bool active: false
    property bool selected: false
    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"

    signal addRequested()
    signal editRequested()

    readonly property real cardRadius: root.iris ? Math.round(14 * IrisStyle.density)
        : Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.editorialEverywhere ? Appearance.rounding.small
        : Appearance.rounding.small

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 20
    radius: cardRadius
    color: root.iris
        ? (root.selected ? ColorUtils.applyAlpha(IrisStyle.accent, 0.16)
            : root.active ? ColorUtils.applyAlpha(IrisStyle.text, 0.055) : "transparent")
        : root.selected ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.10)
            : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.035)
    border.width: root.iris ? 0 : root.selected ? 1 : 0
    border.color: root.iris ? "transparent" : ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.58)

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 10
        }
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            radius: root.cardRadius
            color: root.iris
                ? (root.active ? ColorUtils.applyAlpha(IrisStyle.accent, 0.12) : IrisStyle.surfaceHigh)
                : ColorUtils.applyAlpha(
                    root.active ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1,
                    root.active ? 0.075 : 0.035)

            MaterialSymbol {
                anchors.centerIn: parent
                visible: !["clock", "dateBadge", "editorial", "shape", "visualizer"].includes(root.widgetKey)
                text: root.symbol
                iconSize: 38
                color: root.iris ? (root.active ? IrisStyle.accent : IrisStyle.subtext)
                    : root.active ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                opacity: root.active ? 1 : 0.62
            }

            StyledText {
                anchors.centerIn: parent
                visible: ["clock", "dateBadge", "editorial"].includes(root.widgetKey)
                text: root.widgetKey === "clock" ? "12:48"
                    : root.widgetKey === "dateBadge" ? "MON  09" : "Aa."
                font.pixelSize: root.widgetKey === "editorial" ? 40 : 27
                font.family: Appearance.font.family.main
                font.weight: Font.DemiBold
                color: root.iris ? (root.active ? IrisStyle.accent : IrisStyle.text)
                    : root.active ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                opacity: root.active ? 1 : 0.72
            }

            MaterialShape {
                anchors.centerIn: parent
                visible: root.widgetKey === "shape"
                implicitSize: 54
                shape: MaterialShape.Shape.Flower
                color: root.iris ? (root.active ? IrisStyle.accent : IrisStyle.subtext)
                    : root.active ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                opacity: root.active ? 1 : 0.68
            }

            Row {
                anchors.centerIn: parent
                visible: root.widgetKey === "visualizer"
                spacing: 4
                Repeater {
                    model: [14, 28, 42, 30, 52, 36, 20, 32, 16]
                    Rectangle {
                        required property int modelData
                        width: 5
                        height: modelData
                        y: (52 - height) / 2
                        radius: Math.min(2, width / 2)
                        color: root.iris ? (root.active ? IrisStyle.accent : IrisStyle.subtext)
                            : root.active ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                        opacity: root.active ? 1 : 0.68
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: root.iris ? IrisStyle.text : Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.active ? Translation.tr("On desktop") : Translation.tr("Ready to add")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.iris ? (root.active ? IrisStyle.accent : IrisStyle.muted)
                        : root.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            WidgetEditAction {
                compact: true
                iconName: root.active ? "tune" : "add"
                toggled: root.active
                tooltip: root.active ? Translation.tr("Edit widget") : Translation.tr("Add widget")
                onClicked: root.active ? root.editRequested() : root.addRequested()
            }
        }
    }
}
