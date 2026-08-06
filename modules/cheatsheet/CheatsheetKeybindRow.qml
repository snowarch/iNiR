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
        color: hovered
            ? (Appearance.zzzEverywhere ? Appearance.zzz.bg2
             : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
             : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
             : Appearance.colors.colLayer2Hover)
            : "transparent"
        radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
              : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
              : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
              : Appearance.rounding.verysmall
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
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
            color: Appearance.zzzEverywhere ? Appearance.zzz.ghostInk
                 : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                 : Appearance.colors.colSubtext
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
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
                color: Appearance.zzzEverywhere ? Appearance.zzz.ghostInk
                     : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                     : Appearance.colors.colSubtext
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
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
            color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                 : Appearance.inirEverywhere ? Appearance.inir.colText
                 : Appearance.colors.colOnLayer1
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
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
        color: Appearance.zzzEverywhere ? Appearance.zzz.hairline
             : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
             : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
             : Appearance.colors.colOutlineVariant
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        opacity: Appearance.zzzEverywhere ? 1.0 : 0.3
        visible: root.showDivider
    }
}
