import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    LazyLoader {
        id: popupLoader
        active: GlobalStates.videoEditorPopupOpen

        component: PanelWindow {
            id: popupWindow
            color: "transparent"
            visible: true
            screen: {
                const focused = Quickshell.Hyprland?.focusedMonitor?.name
                if (focused) {
                    const s = Quickshell.screens.find(s => s.name === focused)
                    if (s) return s
                }
                return Quickshell.screens[0]
            }

            WlrLayershell.namespace: "quickshell:videoEditorPopup"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                top: !Config.options.bar.vertical && !Config.options.bar.bottom
                bottom: !Config.options.bar.vertical && Config.options.bar.bottom
                left: Config.options.bar.vertical && !Config.options.bar.bottom
                right: (!Config.options.bar.vertical) || (Config.options.bar.vertical && Config.options.bar.bottom)
            }

            margins {
                top: Config.options.bar.vertical ? 0 : Appearance.sizes.barHeight
                bottom: Config.options.bar.vertical ? 0 : Appearance.sizes.barHeight
                left: Config.options.bar.vertical ? Appearance.sizes.verticalBarWidth : 0
                right: Config.options.bar.vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.hyprlandGapsOut + 4
            }

            implicitWidth: popupContent.implicitWidth
            implicitHeight: popupContent.implicitHeight

            mask: Region {
                item: popupContent.contentBackground
            }

            VideoEditorPopupContent {
                id: popupContent
                onDismissed: GlobalStates.videoEditorPopupOpen = false
                onEditRequested: {
                    GlobalStates.videoEditorPopupOpen = false
                    GlobalStates.videoEditorOpen = true
                }
            }
        }
    }
}
