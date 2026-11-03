import QtQuick
import qs.modules.common
import qs.services

// The plate under a widget. It only says what the widget wants: the active family draws it (part `widgetPlate`), and
// a design that isn't the family's gets the plain one. With `widget: root` it follows that widget's settings.
Item {
    id: root

    property var widget: parent?.look ? parent : null
    property bool shown: true
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        enabled: FamilyStyle.motionEnabled && root.powerActive
        NumberAnimation { duration: plate.item?.moveDuration ?? FamilyStyle.revealDuration }
    }

    // Where it sits on the screen, for the wallpaper behind it.
    property real screenX: root.widget?.x ?? 0
    property real screenY: root.widget?.y ?? 0
    property real screenWidth: root.widget?.scaledScreenWidth ?? 1920
    property real screenHeight: root.widget?.scaledScreenHeight ?? 1080

    property real surfaceOpacity: root.widget?.backgroundOpacity ?? 0.06
    property real surfaceBorderWidth: root.widget?.borderWidth ?? 1
    property real surfaceBorderOpacity: root.widget?.borderOpacity ?? 0.08
    property real surfaceRadius: !root.widget ? 16
        : root.widget.cornerRadiusOverride >= 0 ? root.widget.cornerRadiusOverride : root.widget.widgetCardRadius
    property color surfaceColor: root.widget?.widgetSurfaceInk ?? FamilyStyle.text
    property color surfaceFill: root.widget?.widgetPlateColor ?? FamilyStyle.surface
    property color surfaceAccent: root.widget?.widgetAccent ?? FamilyStyle.accent
    property string colorMode: root.widget?.colorMode ?? "auto"
    property bool surfaceUseBlur: root.widget?.effectiveBlur ?? true
    // Wallpaper brightness behind the widget, 0 to 1, -1 unknown.
    property real regionBrightness: root.widget?.regionBrightness ?? -1
    property bool powerActive: root.widget?.powerActive ?? WidgetPowerManager.widgetsActive

    readonly property string _plateUrl: {
        const own = root.widget?.wearsFamily ?? true
        return own && Plugins.part(Plugins.active, "widgetPlate") || String(Qt.resolvedUrl("WidgetPlate.qml"))
    }
    on_PlateUrlChanged: plate.setSource(root._plateUrl, { surface: root })
    Component.onCompleted: plate.setSource(root._plateUrl, { surface: root })

    Loader {
        id: plate
        anchors.fill: parent
        // A family's plate reads its family's look (DesktopWidgetLook.ready); the plain one reads nothing it lacks.
        active: root.visible && (!(root.widget?.wearsFamily ?? true) || DesktopWidgetLook.ready)
    }
}
