import QtQuick

// The iRiS Design: every primitive keeps its own anatomy, so it declares no parts.
QtObject {
    readonly property string id: "iris"
    readonly property string name: "iRiS"
    readonly property string theme: "iris"
    readonly property string palette: "" // the person's own Style (iris, washi, Material)
    readonly property var parts: ({})
    readonly property var field: ({ corner: "round" })
}
