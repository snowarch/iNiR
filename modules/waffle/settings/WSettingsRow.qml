pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

// Single settings row with label and control - Windows 11 style
Item {
    id: root
    
    property string icon: ""
    property string label: ""
    property string description: ""
    property alias control: controlLoader.sourceComponent
    property bool clickable: false
    property bool showChevron: false
    
    // Settings search integration
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1
    
    signal clicked()
    
    Layout.fillWidth: true
    Layout.leftMargin: 14
    Layout.rightMargin: 14
    implicitHeight: Math.max(52, contentRow.implicitHeight + 20)
    
    // Highlight animation for search focus
    Behavior on opacity {
        enabled: Looks.transition?.opacity !== undefined
        animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
    }
    Behavior on scale {
        enabled: Looks.transition?.resize !== undefined
        animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
    }
    
    function _findSettingsContext(): var {
        var page = null;
        var sectionTitle = "";
        var p = root.parent;
        while (p) {
            if (!page && p.hasOwnProperty("settingsPageIndex")) {
                page = p;
            }
            if (!sectionTitle && p.hasOwnProperty("title") && typeof p.title === "string") {
                sectionTitle = p.title;
            }
            p = p.parent;
        }
        return { page: page, sectionTitle: sectionTitle };
    }
    
    function focusFromSettingsSearch(): void {
        // Find parent Flickable
        var flick = null;
        var p = root.parent;
        while (p) {
            if (p.hasOwnProperty("contentY") && p.hasOwnProperty("contentHeight")) {
                flick = p;
                break;
            }
            p = p.parent;
        }
        
        // Scroll to center this element in view
        if (flick) {
            var y = 0;
            var n = root;
            while (n && n !== flick) {
                y += n.y || 0;
                n = n.parent;
            }
            // Center the element in the viewport
            var centerOffset = (flick.height - root.height) / 2;
            var maxY = Math.max(0, flick.contentHeight - flick.height);
            var target = Math.max(0, Math.min(y - centerOffset, maxY));
            
            // Smooth scroll
            flick.contentY = target;
        }
        
        // Run highlight animation
        highlightAnim.stop();
        root.scale = 1.0;
        highlightOverlay.opacity = 0;
        highlightAnim.start();
    }
    
    Component.onCompleted: {
        if (!enableSettingsSearch) return;
        if (typeof SettingsSearchRegistry === "undefined") return;
        if (!root.label) return;
        
        var ctx = _findSettingsContext();
        var page = ctx.page;
        var sectionTitle = ctx.sectionTitle;
        
        settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: page?.settingsPageIndex ?? -1,
            pageName: page?.settingsPageName ?? "",
            section: sectionTitle,
            label: root.label,
            description: root.description,
            keywords: []
        });
    }
    
    Component.onDestruction: {
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.unregisterControl(root);
        }
    }
    
    Rectangle {
        id: background
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        radius: Looks.radius.medium
        color: {
            if (root.clickable && mouseArea.pressed) return Looks.colors.bg2Active
            if (mouseArea.containsMouse) return Looks.colors.bg2Hover
            return "transparent"
        }
        scale: root.clickable && mouseArea.pressed ? 0.985 : 1.0
        
        Behavior on color {
            animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
        }
        Behavior on scale {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.ultraFast : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
        }
    }
    
    // Highlight overlay for search focus
    Rectangle {
        id: highlightOverlay
        anchors.fill: parent
        radius: Looks.radius.medium
        color: Looks.colors.accent
        opacity: 0
    }

    SequentialAnimation {
        id: highlightAnim
        NumberAnimation { target: highlightOverlay; property: "opacity"; to: 0.18; duration: 200; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 600 }
        NumberAnimation { target: highlightOverlay; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InCubic }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.clickable) root.clicked()
    }
    
    // Bottom separator
    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            leftMargin: root.icon !== "" ? 44 : 16
            rightMargin: 16
        }
        height: 1
        color: Looks.colors.bg2Border
        opacity: mouseArea.containsMouse ? 0.03 : 0.08
        
        Behavior on opacity {
            animation: NumberAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
        }
    }
    
    RowLayout {
        id: contentRow
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 10
        
        FluentIcon {
            visible: root.icon !== ""
            icon: root.icon
            implicitSize: 16
            Layout.alignment: Qt.AlignVCenter
            color: mouseArea.containsMouse ? Looks.colors.accent : Looks.colors.subfg
            
            Behavior on color {
                animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            
            WText {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Looks.font.pixelSize.normal
                elide: Text.ElideRight
            }
            
            WText {
                visible: root.description !== ""
                Layout.fillWidth: true
                text: root.description
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.subfg
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
        }
        
        Loader {
            id: controlLoader
            Layout.alignment: Qt.AlignVCenter
        }
        
        FluentIcon {
            visible: root.showChevron
            icon: "chevron-right"
            implicitSize: 14
            color: Looks.colors.subfg
            opacity: 0.7
        }
    }
}
