pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

// Keybind row with search registration
Item {
    id: root
    
    property var mods: []
    property string keyName: ""
    property string action: ""
    property bool showDivider: true
    property var keySubstitutions: ({})
    
    // Search registration
    property int settingsPageIndex: -1
    property string settingsPageName: ""
    property string settingsSection: ""
    property int settingsSearchOptionId: -1
    
    Layout.fillWidth: true
    implicitHeight: 40
    
    // Highlight animation for search focus
    SequentialAnimation {
        id: highlightAnim
        running: false
        loops: 2
        
        ParallelAnimation {
            NumberAnimation { target: highlightOverlay; property: "opacity"; to: 0.15; duration: 150 }
            NumberAnimation { target: root; property: "scale"; to: 1.01; duration: 150 }
        }
        ParallelAnimation {
            NumberAnimation { target: highlightOverlay; property: "opacity"; to: 0; duration: 150 }
            NumberAnimation { target: root; property: "scale"; to: 1.0; duration: 150 }
        }
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
        
        if (flick) {
            var y = 0;
            var n = root;
            while (n && n !== flick) {
                y += n.y || 0;
                n = n.parent;
            }
            var centerOffset = (flick.height - root.height) / 2;
            var maxY = Math.max(0, flick.contentHeight - flick.height);
            flick.contentY = Math.max(0, Math.min(y - centerOffset, maxY));
        }
        
        highlightAnim.stop();
        root.scale = 1.0;
        highlightOverlay.opacity = 0;
        highlightAnim.start();
    }
    
    Component.onCompleted: {
        if (typeof SettingsSearchRegistry === "undefined") return;
        if (!root.action) return;
        
        // Build key combo string for keywords
        var keyCombo = root.mods.concat(root.keyName ? [root.keyName] : []).join("+").toLowerCase();
        
        settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: root.settingsPageIndex,
            pageName: root.settingsPageName,
            section: root.settingsSection,
            label: root.action,
            description: keyCombo,
            keywords: [keyCombo, "shortcut", "keybind", "hotkey"].concat(root.mods.map(m => m.toLowerCase()))
        });
    }
    
    Component.onDestruction: {
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.unregisterControl(root);
        }
    }
    
    Rectangle {
        anchors.fill: parent
        radius: Looks.radius.medium
        color: rowMouse.containsMouse ? Looks.colors.bg2Hover : "transparent"
    }
    
    Rectangle {
        id: highlightOverlay
        anchors.fill: parent
        radius: Looks.radius.medium
        color: Looks.colors.accent
        opacity: 0
    }
    
    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12
        
        // Keys
        Row {
            Layout.preferredWidth: 180
            Layout.minimumWidth: 120
            spacing: 4
            
            Repeater {
                model: root.mods
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: Math.max(keyText.implicitWidth + 10, 26)
                    implicitHeight: 24
                    radius: Looks.radius.small
                    color: Looks.colors.bg2
                    border.width: 1
                    border.color: Looks.colors.bg2Border
                    
                    WText {
                        id: keyText
                        anchors.centerIn: parent
                        text: root.keySubstitutions[modelData] ?? modelData
                        font.pixelSize: Looks.font.pixelSize.small
                        font.family: Looks.font.family.mono
                    }
                }
            }
            
            WText {
                visible: root.mods.length > 0 && root.keyName.length > 0
                text: "+"
                color: Looks.colors.subfg
                font.pixelSize: Looks.font.pixelSize.small
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Rectangle {
                visible: root.keyName.length > 0
                implicitWidth: Math.max(mainKeyText.implicitWidth + 10, 26)
                implicitHeight: 24
                radius: Looks.radius.small
                color: Looks.colors.bg2
                border.width: 1
                border.color: Looks.colors.bg2Border
                
                WText {
                    id: mainKeyText
                    anchors.centerIn: parent
                    text: root.keySubstitutions[root.keyName] ?? root.keyName
                    font.pixelSize: Looks.font.pixelSize.small
                    font.family: Looks.font.family.mono
                }
            }
        }
        
        // Action
        WText {
            Layout.fillWidth: true
            text: root.action
            font.pixelSize: Looks.font.pixelSize.normal
            elide: Text.ElideRight
        }
    }
    
    // Divider
    Rectangle {
        visible: root.showDivider
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        color: Looks.colors.bg2Border
        opacity: 0.5
    }
}
