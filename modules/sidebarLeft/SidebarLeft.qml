pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.sidebar
import qs.modules.sidebarLeft
import QtQuick
import Quickshell

Scope {
    id: root

    readonly property var targetScreens: {
        const list = Config.options?.sidebar?.screenList ?? []
        const screens = Quickshell.screens
        if (!list || list.length === 0)
            return screens
        const matched = screens.filter(screen => {
            const screenName = screen?.name ?? ""
            return screenName.length > 0 && list.includes(screenName)
        })
        return matched.length > 0 ? matched : screens
    }

    Variants {
        model: root.targetScreens

        SidebarHost {
            required property var modelData
            edge: "left"
            screen: modelData
        }
    }

    // Detached AI chat remains process-global and is owned by one wrapper only.
    Loader {
        active: GlobalStates.aiChatDetached
        sourceComponent: FloatingWindow {
            id: aiChatWindow
            visible: true
            title: "iNiR AI Chat"
            implicitWidth: 520
            implicitHeight: 780
            minimumSize: Qt.size(380, 400)
            color: Appearance.colors.colLayer0

            onVisibleChanged: {
                if (!visible)
                    GlobalStates.aiChatDetached = false
            }

            AiChat {
                anchors.fill: parent
                anchors.margins: 8
            }
        }
    }
}
