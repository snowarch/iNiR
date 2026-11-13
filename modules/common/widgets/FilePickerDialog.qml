pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common

// A file or folder chooser drawn by the shell in the family's look. Qt's own dialog has no native helper here and
// falls back to a white, unthemed window named after its parent. Same surface as QtQuick.Dialogs' FileDialog and
// FolderDialog: title, nameFilters ("Images (*.png *.jpg)"), currentFolder, selectedFile / selectedFolder,
// open(), close(), visible, accepted, rejected. `selectFolder` makes it a folder chooser.
Scope {
    id: root

    property string title: ""
    property list<string> nameFilters: []
    property url currentFolder: ""
    property bool selectFolder: false
    property url selectedFile: ""
    property url selectedFolder: ""
    readonly property bool visible: loader.active

    signal accepted()
    signal rejected()

    function open(): void { loader.active = true }
    function close(): void { loader.active = false }

    function finish(path: string): void {
        const url = "file://" + path
        if (root.selectFolder)
            root.selectedFolder = url
        else
            root.selectedFile = url
        loader.active = false
        root.accepted()
    }
    function cancel(): void {
        loader.active = false
        root.rejected()
    }

    LazyLoader {
        id: loader

        PanelWindow {
            id: window
            screen: GlobalStates.focusedScreen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "inir:filePicker"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            FilePickerSheet {
                anchors.fill: parent
                title: root.title
                nameFilters: root.nameFilters
                startFolder: String(root.currentFolder)
                selectFolder: root.selectFolder
                onChosen: path => root.finish(path)
                onCancelled: root.cancel()
            }
        }
    }
}
