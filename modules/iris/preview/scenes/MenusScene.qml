pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: menuRoot
    readonly property real naturalWidth: Math.round(480 * menuRoot.d)
    readonly property real naturalHeight: Math.round(300 * menuRoot.d)
    readonly property int pad: Math.round(6 * menuRoot.d)
    Plate {
        id: menuPlate
        surface: "menus"
        fallbackRadius: IrisStyle.radiusTile
        anchors.centerIn: parent
        width: Math.round(236 * menuRoot.d)
        height: menuColumn.implicitHeight + 2 * menuRoot.pad
        ColumnLayout {
            id: menuColumn
            x: menuRoot.pad; y: menuRoot.pad
            width: parent.width - 2 * x
            spacing: 0
            ClippingRectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(width * 9 / 16)
                radius: Math.max(IrisStyle.radiusMicro, menuPlate.radius - menuRoot.pad)
                color: IrisStyle.fillQuiet
                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: menuRoot.wallpaperView
                    sourceRect: {
                        const w = menuRoot.wallpaperView.width, h = Math.min(menuRoot.wallpaperView.height, w * 9 / 16)
                        return Qt.rect(0, (menuRoot.wallpaperView.height - h) / 2, w, h)
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.round(parent.height * 0.55)
                    gradient: Gradient {
                        GradientStop { position: 0; color: ColorUtils.applyAlpha(IrisStyle.mediaScrim, 0) }
                        GradientStop { position: 1; color: IrisStyle.veilStrong }
                    }
                }
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Math.round(10 * menuRoot.d)
                    IrisText { Layout.fillWidth: true; text: Translation.tr("Wallpaper"); color: IrisStyle.onMedia; font.pixelSize: IrisStyle.typeLabel; font.weight: IrisStyle.weight(Font.DemiBold) }
                    MaterialSymbol { text: "chevron_right"; iconSize: Math.round(16 * menuRoot.d); color: IrisStyle.onMedia }
                }
            }
            Repeater {
                model: [
                    { sep: true },
                    { glyph: "widgets", text: Translation.tr("Edit widgets"), tint: "teal", lit: true },
                    { glyph: "palette", text: Translation.tr("Customize iRiS"), tint: "purple" },
                    { sep: true },
                    { glyph: "settings", text: Translation.tr("Settings"), tint: "gray" },
                    { glyph: "restart_alt", text: Translation.tr("Restart shell"), tint: "gray" }
                ]
                Item {
                    id: menuRow
                    required property var modelData
                    readonly property color tint: IrisStyle.identityColor(String(menuRow.modelData.tint ?? "gray"))
                    Layout.fillWidth: true
                    implicitHeight: menuRow.modelData.sep ? Math.round(9 * menuRoot.d) : Math.round(28 * menuRoot.d)
                    Rectangle {
                        visible: menuRow.modelData.sep === true
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(8 * menuRoot.d); width: parent.width - 2 * x; height: 1
                        color: IrisStyle.hairline
                    }
                    Rectangle {
                        visible: menuRow.modelData.sep !== true
                        anchors.fill: parent
                        radius: Math.max(IrisStyle.radiusMicro, menuPlate.radius - menuRoot.pad)
                        color: menuRow.modelData.lit ? IrisStyle.fillHover : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(8 * menuRoot.d)
                            spacing: Math.round(8 * menuRoot.d)
                            Rectangle {
                                Layout.preferredWidth: Math.round(18 * menuRoot.d)
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: IrisStyle.iconRadius(width)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: IrisStyle.tileTop(menuRow.tint) }
                                    GradientStop { position: 1; color: menuRow.tint }
                                }
                                MaterialSymbol { anchors.centerIn: parent; text: String(menuRow.modelData.glyph ?? ""); fill: 1; iconSize: Math.round(13 * menuRoot.d); color: IrisStyle.onTint }
                            }
                            IrisText { Layout.fillWidth: true; text: String(menuRow.modelData.text ?? ""); font.pixelSize: IrisStyle.typeLabel }
                        }
                    }
                }
            }
        }
    }
}
