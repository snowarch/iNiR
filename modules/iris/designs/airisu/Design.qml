import QtQuick

// AIRISU (modules/iris/AIRISU.md): the Japanese look around tuning, stickers and seals. Its values are the curated
// Theme `airisu`; its anatomy is the skins below. Coverage is tracked part by part in AIRISU.md.
QtObject {
    readonly property string id: "airisu"
    readonly property string name: "AIRISU"
    readonly property string theme: "airisu"
    // The solver's language for this Design (scripts/colors/washi/airisu.go): lacquer, gofun, the vermilion seal.
    readonly property string palette: "airisu"
    readonly property var parts: ({
        insignia: "parts/Insignia.qml"
    })
    readonly property var field: ({ corner: "round" }) // "chamfer" once the field draws it (AIRISU F3)
}
