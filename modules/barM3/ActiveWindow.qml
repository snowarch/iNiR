import qs.modules.bar as StockBar
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.functions
import QtQuick

// The source component only draws its app icon in vertical mode; horizontally
// it is the same two-line app/title stack, and iNiR's stock one locks both rows
// to baselines and settles the title, so that is the better body. What it did
// not know is that the M3 bar seats it inside a tonal pill, so the ink has to
// come down from the group instead of from the layer.
Item {
    id: root
    readonly property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    implicitWidth: stock.implicitWidth
    implicitHeight: stock.implicitHeight

    StockBar.ActiveWindow {
        id: stock
        anchors.fill: parent
        titleColor: root.isMaterial ? M3Palette.pillInk("activeWindow") : Appearance.colors.colOnLayer0
        appNameColor: root.isMaterial
            ? ColorUtils.readableSubtext(M3Palette.pillInk("activeWindow"),
                M3Palette.pillContainer("activeWindow"), 0.72)
            : Appearance.colors.colSubtext
    }
}
