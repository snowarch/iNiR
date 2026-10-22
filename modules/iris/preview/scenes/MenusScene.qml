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
    subject: Qt.rect(menuPlate.x, menuPlate.y, menuPlate.width, menuPlate.height)
    readonly property real naturalWidth: Math.round(480 * menuRoot.d)
    readonly property real naturalHeight: Math.round(300 * menuRoot.d)
    narrowest: Math.round(320 * menuRoot.d)
    lowest: Math.round(260 * menuRoot.d)
    // The real menu's numbers (IrisDesktopMenu): Menus › Size moves every one of them.
    readonly property bool compact: IrisStyle.menuCompact
    readonly property int pad: Math.round((menuRoot.compact ? 4 : 6) * menuRoot.d)
    readonly property real rowHeight: Math.round((menuRoot.compact ? 28 : 34) * menuRoot.d)
    readonly property real sepHeight: Math.round((menuRoot.compact ? 9 : 13) * menuRoot.d)
    readonly property real markSize: Math.round((menuRoot.compact ? 18 : 20) * menuRoot.d)
    readonly property real glyphSize: Math.round((menuRoot.compact ? 15 : 17) * menuRoot.d)
    readonly property int textSize: menuRoot.compact ? IrisStyle.typeLabel : IrisStyle.typeBody
    Plate {
        id: menuPlate
        surface: "menus"
        // IrisDesktopMenu's own fallback: tile corners when compact, card corners when regular.
        fallbackRadius: menuRoot.compact ? IrisStyle.radiusTile : IrisStyle.radiusCard
        anchors.centerIn: parent
        width: Math.round(224 * menuRoot.d)
        height: menuColumn.implicitHeight + 2 * menuRoot.pad
        ColumnLayout {
            id: menuColumn
            x: menuRoot.pad; y: menuRoot.pad
            width: parent.width - 2 * x
            spacing: 0
            ClippingRectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(width * 0.48)
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
                    { glyph: "widgets", text: Translation.tr("Edit widgets"), tint: "teal", lit: true, code: 1 },
                    { glyph: "palette", text: Translation.tr("Customize iRiS"), tint: "purple", code: 2 },
                    { sep: true },
                    { glyph: "settings", text: Translation.tr("Settings"), tint: "gray", code: 3 },
                    { glyph: "restart_alt", text: Translation.tr("Restart shell"), tint: "gray", code: 4 }
                ]
                Item {
                    id: menuRow
                    required property var modelData
                    readonly property color tint: IrisStyle.identityColor(String(menuRow.modelData.tint ?? "gray"))
                    Layout.fillWidth: true
                    implicitHeight: menuRow.modelData.sep ? menuRoot.sepHeight : menuRoot.rowHeight
                    Rectangle {
                        visible: menuRow.modelData.sep === true
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(8 * menuRoot.d); width: parent.width - 2 * x; height: 1
                        color: IrisStyle.hairline
                    }
                    // A Design that draws menu rows shows its own here (its number, sign and marks), on a stand-in host.
                    Item {
                        id: rowHost
                        visible: menuRow.modelData.sep !== true && IrisDesign.has("menuRow")
                        anchors.fill: parent
                        readonly property var option: ({ text: menuRow.modelData.text, iconName: menuRow.modelData.glyph })
                        readonly property bool lit: menuRow.modelData.lit === true
                        readonly property bool pressed: false
                        readonly property bool marked: true
                        readonly property bool compact: menuRoot.compact
                        readonly property int code: menuRow.modelData.code ?? 0
                        Loader {
                            anchors.fill: parent
                            active: rowHost.visible
                            source: IrisDesign.skin("menuRow")
                            onLoaded: item.host = rowHost
                        }
                    }
                    Rectangle {
                        visible: menuRow.modelData.sep !== true && !IrisDesign.has("menuRow")
                        anchors.fill: parent
                        radius: IrisStyle.radiusRow
                        color: menuRow.modelData.lit ? IrisStyle.fillHover : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round((menuRoot.compact ? 8 : 10) * menuRoot.d)
                            anchors.rightMargin: Math.round((menuRoot.compact ? 10 : 12) * menuRoot.d)
                            spacing: Math.round((menuRoot.compact ? 8 : 10) * menuRoot.d)
                            Rectangle {
                                Layout.preferredWidth: menuRoot.markSize
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: IrisStyle.iconRadius(width)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: IrisStyle.tileTop(menuRow.tint) }
                                    GradientStop { position: 1; color: menuRow.tint }
                                }
                                MaterialSymbol { anchors.centerIn: parent; text: String(menuRow.modelData.glyph ?? ""); fill: 1; iconSize: Math.round(menuRoot.glyphSize * 0.82); color: IrisStyle.onTint }
                            }
                            IrisText { Layout.fillWidth: true; text: String(menuRow.modelData.text ?? ""); font.pixelSize: menuRoot.textSize; font.weight: IrisStyle.weight(Font.Medium) }
                        }
                    }
                }
            }
        }
    }
    Caption {
        glyph: "menu_open"
        text: menuRoot.compact ? Translation.tr("Compact menus") : Translation.tr("Regular menus")
    }
}
