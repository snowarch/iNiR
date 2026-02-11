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
    Layout.leftMargin: 16
    Layout.rightMargin: 16
    implicitHeight: Math.max(48, contentRow.implicitHeight + 14)
    
    // Highlight animation for search focus
    Behavior on opacity {
        enabled: Looks.transition?.opacity !== undefined
        animation: Looks.transition.opacity.createObject(this)
    }
    Behavior on scale {
        enabled: Looks.transition?.resize !== undefined
        animation: Looks.transition.resize.createObject(this)
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
        radius: Looks.radius.medium
        color: root.clickable && mouseArea.containsMouse 
            ? Looks.colors.bg2Hover 
            : "transparent"
        
        Behavior on color {
            animation: Looks.transition.color.createObject(this)
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
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
    
    // Bottom separator
    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            leftMargin: root.icon !== "" ? 40 : 12
            rightMargin: 12
        }
        height: 1
        color: Looks.colors.bg2Border
        opacity: 0.35
    }
    
    RowLayout {
        id: contentRow
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 12
        
        FluentIcon {
            visible: root.icon !== ""
            icon: root.icon
            implicitSize: 16
            color: Looks.colors.subfg
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
            }
        }
        
        Loader {
            id: controlLoader
            Layout.alignment: Qt.AlignVCenter
        }
        
        FluentIcon {
            visible: root.showChevron
            icon: "chevron-right"
            implicitSize: 16
            color: Looks.colors.subfg
        }
    }
}
