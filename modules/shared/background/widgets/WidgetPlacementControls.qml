pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

// Where a widget sits and what can be done to it: anchor, free or quietest spot, scale and
// opacity, then lock, front, reset and remove. The same page answers "More actions" and a right click,
// so nothing here opens a popup window over the desktop layer.
ColumnLayout {
    id: root
    required property var widget
    property bool wide: false

    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    readonly property real d: root.iris ? IrisStyle.density : 1
    readonly property var zoneGlyphs: ({ topLeft: "north_west", topCenter: "north", topRight: "north_east",
        centerLeft: "west", center: "filter_center_focus", centerRight: "east",
        bottomLeft: "south_west", bottomCenter: "south", bottomRight: "south_east" })
    readonly property var zoneNames: ({ topLeft: "Top left", topCenter: "Top center", topRight: "Top right",
        centerLeft: "Center left", center: "Center", centerRight: "Center right",
        bottomLeft: "Bottom left", bottomCenter: "Bottom center", bottomRight: "Bottom right" })

    spacing: Math.round(14 * root.d)
    implicitWidth: Math.round(320 * root.d)

    WidgetQuickSection {
        title: Translation.tr("Position")
        detail: "X " + Math.round(root.widget.x) + "  Y " + Math.round(root.widget.y)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(10 * root.d)

            WidgetQuickChoices {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(120 * root.d)
                maxColumns: 3
                current: root.widget.placementStrategy
                model: (root.widget._snapZones ?? []).map(zone => ({ value: zone, icon: root.zoneGlyphs[zone],
                    tooltip: Translation.tr(root.zoneNames[zone]) }))
                onPicked: value => root.widget.snapToZone(value)
            }
            WidgetQuickChoices {
                Layout.alignment: Qt.AlignTop
                maxColumns: 1
                current: root.widget.placementStrategy
                model: [
                    { value: "free", icon: "open_with", label: Translation.tr("Free") },
                    { value: "leastBusy", icon: "auto_awesome", label: Translation.tr("Quietest spot") }
                ]
                onPicked: value => {
                    if (value === "free")
                        root.widget._setOutputValues({ placementStrategy: "free",
                            x: Math.round(root.widget.x), y: Math.round(root.widget.y) })
                    else
                        root.widget._setOutputValue("placementStrategy", value)
                }
            }
        }
    }

    WidgetQuickSlider {
        title: Translation.tr("Scale")
        from: 50; to: 200; stepSize: 5; unit: "%"
        value: Math.round(root.widget._baseScale * 100)
        onMoved: v => root.widget.previewIrisValue("widgetScale", v)
        onCommitted: v => root.widget.commitIrisValue("widgetScale", v)
    }

    WidgetQuickSlider {
        title: Translation.tr("Opacity")
        from: 10; to: 100; stepSize: 5; unit: "%"
        value: Math.round(root.widget.widgetOpacity * 100)
        onMoved: v => root.widget.previewIrisValue("widgetOpacity", v)
        onCommitted: v => root.widget.commitIrisValue("widgetOpacity", v)
    }

    WidgetQuickSection {
        title: Translation.tr("Arrange")
        detail: Math.round(root.widget.width) + " × " + Math.round(root.widget.height)

        WidgetQuickChoices {
            maxColumns: 2
            isSelected: entry => entry.value === "lock" && root.widget.locked
            model: [
                { value: "lock", icon: root.widget.locked ? "lock" : "lock_open",
                    label: root.widget.locked ? Translation.tr("Locked") : Translation.tr("Lock") },
                { value: "front", icon: "flip_to_front", label: Translation.tr("To front") },
                { value: "reset", icon: "restart_alt", label: Translation.tr("Reset") },
                { value: "remove", icon: "remove_circle", label: Translation.tr("Remove"), danger: true }
            ]
            onPicked: value => {
                if (value === "lock") root.widget._setOutputValue("locked", !root.widget.locked)
                else if (value === "front") root.widget._bringToFront()
                else if (value === "reset") root.widget.resetToDefaults()
                else if (value === "remove") {
                    root.widget.closeQuickControls()
                    DesktopWidgetLayout.setGloballyEnabled(root.widget.configEntryName, false)
                }
            }
        }
    }
}
