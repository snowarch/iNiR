import QtQuick
import qs.modules.common
import qs.services

// Lit only while a setting differs from a fresh install: the changed value is the loud one, and this puts it back.
// It keeps its place while dark, so the control beside it never moves under the pointer.
RippleButton {
    id: root

    property string path: ""
    property string label: ""
    // A key at the end of a flow can come and go without moving anything.
    property bool keepPlace: true
    readonly property string _says: root.label.length > 0 ? Translation.tr("Reset %1").arg(root.label) : Translation.tr("Reset to default")
    readonly property bool changed: root.path.length > 0 && ConfigFactory.ready && Config.revision >= 0
        && ConfigFactory.isChanged(root.path)

    visible: root.keepPlace ? root.path.length > 0 : root.changed
    enabled: root.changed
    opacity: root.changed ? 1 : 0
    implicitWidth: 28
    implicitHeight: 28
    buttonRadius: Appearance.rounding.full
    colBackground: "transparent"
    releaseAction: () => ConfigFactory.resetWithUndo(root.path, root.label)
    Accessible.name: root._says
    Component.onCompleted: if (root.path.length > 0) ConfigFactory.load()

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        text: "restart_alt"
        iconSize: Appearance.font.pixelSize.large
        color: Appearance.colors.colPrimary
    }

    StyledToolTip {
        text: root._says
    }
}
