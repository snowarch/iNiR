pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

/**
 * Single keybind row following M3 typography patterns.
 */
Item {
    id: root
    
    required property var keybindData
    property var keyBlacklist: ["Super_L"]
    property var keySubstitutions: ({})
    property bool showDivider: true
    
    readonly property string category: keybindData?.category ?? ""
    readonly property string mainKey: keybindData?.key ?? ""
    readonly property var modifiers: keybindData?.mods ?? []
    readonly property string description: keybindData?.comment ?? ""
    readonly property bool hasModifiers: modifiers.length > 0
    readonly property bool showMainKey: !keyBlacklist.includes(mainKey)
    
    implicitHeight: rowContent.height + (showDivider ? divider.height : 0)
    
    property bool hovered: hoverArea.containsMouse
    
    Rectangle {
        anchors.fill: rowContent
        color: hovered ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.colors.colLayer2Hover) : "transparent"
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
    
    MouseArea {
        id: hoverArea
        anchors.fill: rowContent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
    
    RowLayout {
        id: rowContent
        width: parent.width
        height: 40
        spacing: 16
        
        // Category column - flexible width
        StyledText {
            Layout.preferredWidth: 140
            Layout.minimumWidth: 100
            Layout.alignment: Qt.AlignVCenter
            text: root.category
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            elide: Text.ElideRight
            leftPadding: 16
        }
        
        // Keys column - flexible width for keys
        Row {
            Layout.preferredWidth: 220
            Layout.minimumWidth: 150
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
            
            Repeater {
                model: root.modifiers
                delegate: KeyboardKey {
                    required property var modelData
                    key: root.keySubstitutions[modelData] ?? modelData
                }
            }
            
            StyledText {
                visible: root.showMainKey && root.hasModifiers
                text: "+"
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Appearance.font.pixelSize.small
            }
            
            KeyboardKey {
                visible: root.showMainKey
                key: root.keySubstitutions[root.mainKey] ?? root.mainKey
            }
        }
        
        // Description column - takes remaining space
        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            text: root.description
            elide: Text.ElideRight
            rightPadding: 16
        }
    }
    
    Rectangle {
        id: divider
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 12
            rightMargin: 12
        }
        height: 1
        color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle : Appearance.colors.colOutlineVariant
        opacity: 0.3
        visible: root.showDivider
    }
}
