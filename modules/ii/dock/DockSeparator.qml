import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property real padding: 5
    property string dockPosition: "bottom"
    readonly property string surfaceDialect: Appearance.surfaceDialectFor(
        Config.options?.dock?.style === "island" ? "island" : "")
    readonly property bool zzzStyle: surfaceDialect === "zzz"
    readonly property bool angelStyle: surfaceDialect === "angel"
    readonly property bool inirStyle: surfaceDialect === "inir"
    readonly property bool auroraStyle: surfaceDialect === "aurora" || angelStyle
    
    readonly property real dockHeight: Config.options?.dock?.height ?? 70
    readonly property real separatorSize: dockHeight - 50
    
    // Exactamente igual que el separador en DockAppButton
    implicitWidth: vertical ? separatorSize : 8
    implicitHeight: vertical ? 8 : separatorSize
    
    Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    // Margen extra para igualar el espacio del separador de apps (que tiene 8px total con spacing 2 = 3px extra cada lado)
    Layout.topMargin: vertical ? 3 : 0
    Layout.bottomMargin: vertical ? 3 : 0
    Layout.leftMargin: !vertical ? 3 : 0
    Layout.rightMargin: !vertical ? 3 : 0
    
    Rectangle {
        anchors.centerIn: parent
        width: root.vertical ? root.separatorSize : 1
        height: root.vertical ? 1 : root.separatorSize
        color: root.zzzStyle ? Appearance.zzz.hairlineStrong
             : root.angelStyle ? Appearance.angel.colCardBorder
             : root.inirStyle ? Appearance.inir.colBorderSubtle
             : root.auroraStyle ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.7)
             : Appearance.colors.colOutlineVariant
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    }
}
