import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.modules.sidebarRight.quickToggles.classicStyle

AbstractQuickPanel {
    id: root
    property bool compactMode: false
    
    implicitHeight: grid.implicitHeight
    Layout.fillWidth: true

    Grid {
        id: grid
        anchors.top: parent.top
        anchors.horizontalCenter: root.compactMode ? undefined : parent.horizontalCenter
        anchors.left: root.compactMode ? parent.left : undefined
        anchors.right: root.compactMode ? parent.right : undefined
        width: root.compactMode ? parent.width : implicitWidth
        
        // Approximate width of a toggle (40) + spacing (12)
        property int itemSlotWidth: 52 
        columns: Math.max(1, Math.floor((root.compactMode ? grid.width : root.width) / itemSlotWidth))
        
        spacing: root.compactMode ? 8 : 12
        
        NetworkToggle {
            altAction: () => root.openWifiDialog()
        }
        
        BluetoothToggle {
            altAction: () => root.openBluetoothDialog()
        }
        
        NightLight {
            altAction: () => root.openNightLightDialog()
        }
        
        EasyEffectsToggle {
            altAction: () => Quickshell.execDetached(["easyeffects"])
        }
        
        IdleInhibitor {}
        
        GameMode {}
        
        CloudflareWarp {}
    }
}
