import QtQuick

// iRiS's picture in Settings › Design, in its own pigments whatever Design is on: the Island melted into the top
// edge, round, with the ring mark and the time, and a Control Center hanging from it over a soft night.
Rectangle {
    id: root
    readonly property real u: height / 100
    gradient: Gradient {
        GradientStop { position: 0; color: "#1b2233" }   // iris-literal: a night wallpaper, the picture's own
        GradientStop { position: 1; color: "#3a2a44" }   // iris-literal: a night wallpaper, the picture's own
    }
    Rectangle {
        id: island
        width: 64 * root.u; height: 13 * root.u
        x: (root.width - width) / 2; y: -1
        radius: height / 2
        color: "#000000" // iris-literal: iRiS's black body
        Rectangle {
            x: 4 * root.u; anchors.verticalCenter: parent.verticalCenter
            width: 6 * root.u; height: width; radius: width / 2
            color: "transparent"; border.width: Math.max(1, 0.9 * root.u); border.color: "#8ab4ff" // iris-literal: iRiS accent
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 5 * root.u; anchors.verticalCenter: parent.verticalCenter
            text: "9:41"; color: "#f2f2f7"; font.family: "Inter Display"; font.weight: Font.DemiBold; font.pixelSize: 5.6 * root.u // iris-literal: iRiS ink
        }
    }
    Rectangle {
        width: 74 * root.u; height: 54 * root.u
        x: (root.width - width) / 2; y: 18 * root.u
        radius: 10 * root.u
        color: "#000000" // iris-literal: iRiS's black body
        Grid {
            x: 6 * root.u; y: 6 * root.u
            columns: 2; spacing: 4 * root.u
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 29 * root.u; height: 12 * root.u; radius: height / 2
                    color: index === 0 ? "#8ab4ff" : "#1c1c1e" // iris-literal: iRiS accent and fill
                }
            }
        }
        Rectangle {
            x: 6 * root.u; y: 40 * root.u; width: 62 * root.u; height: 8 * root.u; radius: height / 2; color: "#1c1c1e" // iris-literal: iRiS fill
            Rectangle { width: parent.width * 0.62; height: parent.height; radius: height / 2; color: "#f2f2f7" } // iris-literal: iRiS ink
        }
    }
    Text {
        x: 6 * root.u; anchors.bottom: parent.bottom; anchors.bottomMargin: 5 * root.u
        text: "iRiS"; color: "#f2f2f7"; font.family: "Inter Display"; font.weight: Font.Bold; font.pixelSize: 11 * root.u // iris-literal: iRiS ink
    }
}
