import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// ============================================================================
// LENOVO CONSERVATION MODE BAR MODULE
// ============================================================================
// Robust implementation matching the BatteryIndicator popup pattern.
// ============================================================================

MouseArea {
    id: root
    
    // --- Properties ---
    property bool compact: false
    property bool showLabel: true
    property real iconSize: Appearance.font.pixelSize.large
    
    // --- State Mapping ---
    enabled: LenovoService.available
    visible: LenovoService.available
    hoverEnabled: true

    // --- Dynamic Sizing ---
    // Fixing the "hardcoded" space issue: width is 0 if module is disabled
    implicitHeight: Appearance.sizes.barHeight
    implicitWidth: (visible && (Config.options?.bar?.modules?.lenovoConservation ?? true)) 
        ? (contentLayout.implicitWidth + 20) 
        : 0

    // --- Action ---
    onClicked: LenovoService.toggle()

    // --- Layout ---
    RowLayout {
        id: contentLayout
        spacing: 8
        anchors.centerIn: parent
        visible: root.implicitWidth > 0

        MaterialSymbol {
            id: symbol
            text: LenovoService.isActive ? "shield_with_heart" : "shield"
            iconSize: root.iconSize
            fill: LenovoService.isActive ? 1 : 0
            
            color: LenovoService.isActive 
                ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2)
            
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        StyledText {
            visible: !root.compact && root.showLabel
            text: LenovoService.isActive ? Translation.tr("Conserve") : Translation.tr("Standard")
            font.bold: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: LenovoService.isActive 
                ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2)
        }
    }

    // --- Native Ripple Effect ---
    RippleButton {
        id: rippleProvider
        anchors.fill: parent
        colBackground: "transparent"
        colBackgroundHover: "transparent"
        rippleEnabled: true
        onClicked: LenovoService.toggle()
        buttonRadius: Appearance.rounding.small
        visible: root.implicitWidth > 0
    }

    // --- Popup (Matches Battery Indicator) ---
    // Referenced directly as it's in the same directory now
    LenovoPopup {
        id: lenovoPopup
        hoverTarget: root
    }

    // --- Loading State ---
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Qt.rgba(0,0,0,0.4)
        visible: LenovoService.loading && root.implicitWidth > 0

        MaterialLoadingIndicator {
            anchors.centerIn: parent
            width: parent.height * 0.5
            height: width
        }
    }
}
