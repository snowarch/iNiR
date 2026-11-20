pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
SelectionGroupButton {
    id: root
    // iRiS: quiet translucent choices on black, the accent marks the selected one
    // (the same pairing as the edit toolbar's committing action).
    readonly property var look: DesktopWidgetLook.look
    readonly property color _accent: root.look.accent ?? FamilyStyle.accent
    readonly property color _onAccent: ColorUtils.contrastRatio("#ffffff", root._accent) >= ColorUtils.contrastRatio("#101318", root._accent)
        ? "#ffffff" : "#101318"
    implicitHeight: 32

    // Override the inherited family-aware bindings only while iRiS owns this
    // control. Restore them verbatim when the panel family changes at runtime.
    Binding { target: root; property: "colBackground"; value: ColorUtils.applyAlpha(FamilyStyle.text, 0.08); when: root.look.tintedKeys; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colBackgroundHover"; value: ColorUtils.applyAlpha(FamilyStyle.text, 0.14); when: root.look.tintedKeys; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colBackgroundActive"; value: ColorUtils.applyAlpha(FamilyStyle.text, 0.2); when: root.look.tintedKeys; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colBackgroundToggled"; value: root._accent; when: root.look.tintedKeys; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colBackgroundToggledHover"; value: Qt.lighter(root._accent, 1.08); when: root.look.tintedKeys; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colTextOverride"; value: root.look.controlInk; when: root.look.tintedKeys; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colTextToggledOverride"; value: root._onAccent; when: root.look.tintedKeys; restoreMode: Binding.RestoreBinding }
    StyledToolTip { text: root.buttonText }
}
