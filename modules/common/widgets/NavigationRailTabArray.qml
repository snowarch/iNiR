import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property int currentIndex: 0
    property bool expanded: false
    default property alias contentData: tabBarColumn.data
    implicitHeight: tabBarColumn.implicitHeight
    implicitWidth: tabBarColumn.implicitWidth
    Layout.topMargin: 25

    Rectangle {
        property real itemHeight: (tabBarColumn.children.length > 0) ? (tabBarColumn.children[0]?.baseSize ?? 56) : 56
        property real baseHighlightHeight: (tabBarColumn.children.length > 0) ? (tabBarColumn.children[0]?.baseHighlightHeight ?? 56) : 56
        visible: tabBarColumn.children.length > 0 && root.currentIndex < tabBarColumn.children.length
        anchors {
            top: tabBarColumn.top
            left: tabBarColumn.left
            topMargin: itemHeight * root.currentIndex + (root.expanded ? 0 : ((itemHeight - baseHighlightHeight) / 2))
        }
        radius: Appearance.rounding.full
        // Bgless doctrine: no selection pill behind the icon. The active item is
        // signalled by the icon's accent colour (see NavigationRailButton).
        color: "transparent"
        implicitHeight: root.expanded ? itemHeight : baseHighlightHeight
        implicitWidth: visible ? (tabBarColumn.children[root.currentIndex]?.visualWidth ?? 56) : 0

        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
    }

    ColumnLayout {
        id: tabBarColumn
        anchors.fill: parent
        spacing: 0
    }
}
