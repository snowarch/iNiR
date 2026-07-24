pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

Scope {
    id: root

    function dismiss() {
        GlobalStates.regionSelectorOpen = false
    }

    readonly property var action: GlobalStates.regionSelectorAction
    readonly property var selectionMode: GlobalStates.regionSelectorMode
    
    Variants {
        model: Quickshell.screens
        delegate: Loader {
            id: regionSelectorLoader
            required property var modelData
            active: GlobalStates.regionSelectorOpen

            sourceComponent: RegionSelection {
                screen: regionSelectorLoader.modelData
                onDismiss: root.dismiss()
                action: root.action
                selectionMode: root.selectionMode
            }
        }
    }

    // Unified capture+crop+annotate flow for screenshotEdit. Separate from
    // RegionSelection so the other actions (copy/search/ocr/record) are untouched.
    Variants {
        model: Quickshell.screens
        delegate: Loader {
            id: screenshotEditorLoader
            required property var modelData
            active: GlobalStates.screenshotEditorOpen

            sourceComponent: ScreenshotEditor {
                screen: screenshotEditorLoader.modelData
                onDismiss: GlobalStates.screenshotEditorOpen = false
            }
        }
    }

    // Native annotation editor (Edit action). Lives in this Scope so it survives
    // the selection overlay dismissing.
    Loader {
        active: GlobalStates.annotationEditorOpen
        sourceComponent: AnnotationEditor {}
    }

}
