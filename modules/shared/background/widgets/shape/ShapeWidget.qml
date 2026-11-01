pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "shape"
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

}
