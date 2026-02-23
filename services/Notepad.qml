pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Simple persistent notepad for inir.
 * Stores a single text buffer on disk under Directories.notepadPath.
 */
Singleton {
    id: root

    property string filePath: Directories.notepadPath
    property string text: ""

    function setTextValue(newText) {
        text = newText
        notepadFileView.setText(text)
    }

    function refresh() {
        notepadFileView.reload()
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: notepadFileView
        path: Qt.resolvedUrl(root.filePath)

        onLoaded: {
            const fileContents = notepadFileView.text()
            root.text = fileContents
        }

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                console.log("[Notepad] File not found, creating new file.")
                // Ensure parent directory exists
                const parentDir = root.filePath.substring(0, root.filePath.lastIndexOf('/'))
                Process.exec(["/usr/bin/mkdir", "-p", parentDir])
                root.text = ""
                notepadFileView.setText(root.text)
            } else {
                console.log("[Notepad] Error loading file:", error)
            }
        }
    }
}
