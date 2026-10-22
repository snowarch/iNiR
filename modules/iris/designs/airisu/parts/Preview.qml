import QtQuick
import qs.modules.iris.style
import QtQuick.Shapes

// AIRISU's picture in Settings › Design, in its own pigments whatever Design is on (a Design shows what it is): the
// three plates of its bar, the kamon and the wordmark, and one sticker, the body stripe at −24°.
Rectangle {
    id: root
    readonly property real u: height / 100
    color: "#0b0b0c" // iris-literal: 漆黒, AIRISU's own pigment in its picture

    component Plate: Shape {
        property real cut: 3 * root.u
        property bool leftCut: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "#141416" // iris-literal: 墨
            strokeColor: "transparent"
            startX: 0; startY: 0
            PathLine { x: width; y: 0 }
            PathLine { x: width; y: height - (leftCut ? 0 : cut) }
            PathLine { x: width - (leftCut ? 0 : cut); y: height }
            PathLine { x: leftCut ? cut : 0; y: height }
            PathLine { x: 0; y: height - (leftCut ? cut : 0) }
            PathLine { x: 0; y: 0 }
        }
    }
    // The bar: workspaces left, the wedge with the chevrons in the middle, the clock right.
    Plate { x: 4 * root.u; y: 4 * root.u; width: 34 * root.u; height: 11 * root.u }
    Rectangle { x: 7 * root.u; y: 6.5 * root.u; width: 6 * root.u; height: width; radius: width / 2; color: "#e9e6df" } // iris-literal: 胡粉
    Repeater {
        model: 3
        Rectangle { required property int index; x: (17 + index * 6) * root.u; y: 8.5 * root.u; width: 2 * root.u; height: width; radius: width / 2; color: "#5a5a5e" } // iris-literal: an idle workspace
    }
    Plate { x: (root.width - width) / 2; y: 4 * root.u; width: 70 * root.u; height: 11 * root.u; leftCut: false }
    Text { x: root.width / 2 - 30 * root.u; y: 5.6 * root.u; text: "❯❯"; color: "#e5341b"; font.pixelSize: 6 * root.u; font.weight: Font.Black } // iris-literal: 朱
    Rectangle { x: root.width / 2 - 18 * root.u; y: 9.2 * root.u; width: 44 * root.u; height: Math.max(1, 0.8 * root.u); color: "#2a2b2e" } // iris-literal: 鉄
    Rectangle { x: root.width / 2 - 18 * root.u; y: 9.2 * root.u; width: 20 * root.u; height: Math.max(1, 0.8 * root.u); color: "#e9e6df" } // iris-literal: 胡粉
    Plate { x: root.width - width - 4 * root.u; y: 4 * root.u; width: 34 * root.u; height: 11 * root.u; leftCut: false }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 7 * root.u; y: 5.2 * root.u
        text: "23:59"; color: "#e9e6df"; font.family: IrisStyle.fontDot; font.weight: Font.Normal; font.pixelSize: 6.6 * root.u // iris-literal: 胡粉
    }

    // The mark.
    Insignia {
        id: mark
        x: 12 * root.u; y: 36 * root.u
        width: 34 * root.u; height: width
        ink: "#e9e6df"          // iris-literal: 胡粉
        sealColour: "#e5341b"   // iris-literal: 朱
    }
    Column {
        anchors.left: mark.right; anchors.leftMargin: 8 * root.u
        anchors.verticalCenter: mark.verticalCenter
        spacing: 1.5 * root.u
        Text {
            text: "airisu"; color: "#e9e6df" // iris-literal: 胡粉
            font.family: IrisStyle.fontRead; font.weight: Font.DemiBold; font.pixelSize: 22 * root.u
            font.letterSpacing: -0.9 * root.u
        }
        Row {
            spacing: 3 * root.u
            Text { text: "アイリス"; color: "#e9e6df"; font.family: "Noto Sans CJK JP"; font.weight: Font.Bold; font.pixelSize: 5 * root.u } // iris-literal: 胡粉
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8 * root.u; height: 1; color: "#5a5a5e" } // iris-literal: a rule
            Text { text: "NIGHT SPEC"; color: "#a5a29b"; font.family: IrisStyle.fontLabel; font.pixelSize: 4.4 * root.u; font.letterSpacing: 1.4 * root.u } // iris-literal: data
        }
    }

    // The sticker: three lines at −24°, 14, 6 and 3 units.
    Item {
        x: root.width - 74 * root.u; y: root.height - 18 * root.u
        width: 70 * root.u; height: 14 * root.u
        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -Math.tan(24 * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        Rectangle { x: 6 * root.u; width: parent.width - x; height: 3.4 * root.u; color: "#e5341b" } // iris-literal: 朱
        Rectangle { x: 14 * root.u; y: 5.4 * root.u; width: parent.width - x; height: 1.5 * root.u; color: "#e9e6df" } // iris-literal: 胡粉
        Rectangle { x: 20 * root.u; y: 8.6 * root.u; width: parent.width - x; height: Math.max(1, 0.8 * root.u); color: "#e9e6df" } // iris-literal: 胡粉
    }
}
