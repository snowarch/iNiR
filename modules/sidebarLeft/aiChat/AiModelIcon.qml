import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/**
 * Renders a model/provider icon, transparently handling both kinds iNiR uses:
 *  - theme SVGs in assets/icons (e.g. "spark-symbolic", "google-gemini-symbolic")
 *    → drawn with CustomIcon (IconImage).
 *  - Material Symbol glyph names (e.g. "smart_toy", "neurology")
 *    → drawn with MaterialSymbol.
 *
 * The model catalog mixes both, so a plain MaterialSymbol would print literal
 * text for SVG names and a plain CustomIcon would fail to open glyph names.
 */
Item {
    id: root
    property string icon: ""
    property real size: 18
    property color color: Appearance.colors.colOnLayer1

    implicitWidth: size
    implicitHeight: size

    // Theme SVG icons in iNiR are named "*-symbolic"; everything else is treated
    // as a Material glyph.
    readonly property bool isThemeIcon: root.icon.endsWith("-symbolic")

    CustomIcon {
        anchors.centerIn: parent
        visible: root.isThemeIcon && root.icon.length > 0
        width: root.size
        height: root.size
        // Bare icon name (no extension) — matches every other CustomIcon caller
        // in iNiR; IconImage resolves the file under assets/icons.
        source: root.isThemeIcon ? root.icon : ""
        colorize: true
        color: root.color
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: !root.isThemeIcon && root.icon.length > 0
        text: root.icon
        iconSize: root.size
        color: root.color
    }
}
