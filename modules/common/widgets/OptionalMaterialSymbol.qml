pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Zero-size icon slot when no symbol is configured.
 *
 * This used to be a Loader for a single MaterialSymbol. Settings pages are
 * retained and released aggressively, so those tiny Loaders were frequently
 * destroyed while an asynchronously loaded neighbour page was still
 * incubating, producing a large amount of lifecycle noise. A direct item is
 * cheaper and has no asynchronous component lifetime to cancel.
 */
Item {
    id: root

    required property string icon
    property real iconSize: Appearance.font.pixelSize.larger
    readonly property bool hasIcon: root.icon.length > 0

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: root.hasIcon ? materialSymbol.implicitWidth : 0
    implicitHeight: root.hasIcon ? materialSymbol.implicitHeight : 0
    visible: root.hasIcon

    MaterialSymbol {
        id: materialSymbol
        anchors.centerIn: parent
        text: root.icon
        iconSize: root.iconSize
        color: Appearance.colors.colOnSurface
    }
}
