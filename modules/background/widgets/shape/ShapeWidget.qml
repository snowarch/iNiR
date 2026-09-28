pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "shape"
    defaultConfig: ({ placementStrategy: "free", contentWidth: 160, contentHeight: 160,
        shape: "Flower", treatment: "flat", outline: false, angle: 0, strokeWidth: 3,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: false, showBorder: false, backgroundOpacity: 0,
        borderWidth: 0, borderOpacity: 0.2, cornerRadius: -1, useBlur: false, x: 80, y: 240 })
    implicitWidth: Math.max(64, Number(root._readConfigKey("contentWidth") ?? 160)) * scaleFactor
    implicitHeight: Math.max(64, Number(root._readConfigKey("contentHeight") ?? 160)) * scaleFactor
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 64
    resizeMinHeight: 64
    readonly property string shapeName: String(root._readConfigKey("shape") ?? "Flower")
    readonly property string treatment: String(root._readConfigKey("treatment") ?? "flat")
    readonly property bool outline: Boolean(root._readConfigKey("outline") ?? false)
    readonly property real angle: Number(root._readConfigKey("angle") ?? 0)
    readonly property real lineWidth: Math.max(1, Number(root._readConfigKey("strokeWidth") ?? 3)) * scaleFactor

    MaterialShape {
        id: silhouette
        anchors.centerIn: parent
        implicitSize: Math.max(1, (Math.min(root.width, root.height) - root.lineWidth * 2)
            / (Math.abs(Math.cos(root.angle * Math.PI / 180)) + Math.abs(Math.sin(root.angle * Math.PI / 180))))
        shape: DesktopWidgetShapes.shapeForName(root.shapeName)
        color: root.outline ? "transparent" : root.widgetAccent
        strokeColor: root.outline ? root.widgetAccent : "transparent"
        strokeWidth: root.outline ? root.lineWidth : 0
        rotation: root.angle
    }

    MaterialShape {
        anchors.centerIn: parent
        visible: !root.outline && root.treatment !== "flat"
        implicitSize: silhouette.implicitSize * (root.treatment === "inset" ? 0.70 : 0.52)
        shape: root.treatment === "inset" ? silhouette.shape : MaterialShape.Shape.Circle
        color: root.treatment === "inset"
            ? root.widgetSemanticContainer(root.widgetPrimaryRole)
            : root.widgetAccent3
        rotation: root.angle
    }

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Shape")
                WidgetShapePicker {
                    Layout.fillWidth: true
                    selectedShape: root.shapeName
                    onShapeSelected: name => root._setOutputValue("shape", name)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Fill")
                WidgetQuickChoices {
                    current: root.outline
                    model: [
                        { value: false, icon: "circle", label: Translation.tr("Filled") },
                        { value: true, icon: "radio_button_unchecked", label: Translation.tr("Outline") }
                    ]
                    onPicked: value => root._setOutputValue("outline", value)
                }
                WidgetQuickChoices {
                    visible: !root.outline
                    current: root.treatment
                    model: [
                        { value: "flat", label: Translation.tr("Solid") },
                        { value: "inset", label: Translation.tr("Inset") },
                        { value: "duotone", label: Translation.tr("Duotone") }
                    ]
                    onPicked: value => Config.setNestedValue("background.widgets.shape.treatment", value)
                }
            }
            WidgetQuickSlider {
                title: Translation.tr("Rotation")
                from: 0; to: 360; stepSize: 15; unit: "°"
                value: root.angle
                onMoved: v => root.previewIrisValue("angle", v)
                onCommitted: v => root.commitIrisValue("angle", v)
            }
        }
    }
}
