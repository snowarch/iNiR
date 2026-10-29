import QtQuick
import qs.modules.common
import qs.services

// Shown only while a setting differs from a fresh install: the changed value is the loud one, and this puts it back.
RippleButton {
    id: root

    property string path: ""
    property string label: ""
    readonly property bool changed: root.path.length > 0 && ConfigFactory.ready && Config.revision >= 0
        && ConfigFactory.isChanged(root.path)

    visible: root.changed
    implicitWidth: 28
    implicitHeight: 28
    buttonRadius: Appearance.rounding.full
    colBackground: "transparent"
    releaseAction: () => ConfigFactory.reset(root.path)
    Accessible.name: Translation.tr("Reset %1").arg(root.label)
    Component.onCompleted: if (root.path.length > 0) ConfigFactory.load()

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        text: "restart_alt"
        iconSize: Appearance.font.pixelSize.large
        color: Appearance.colors.colPrimary
    }

    StyledToolTip {
        text: Translation.tr("Reset %1").arg(root.label)
    }
}
