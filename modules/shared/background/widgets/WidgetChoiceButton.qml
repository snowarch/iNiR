pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

SelectionGroupButton {
    id: root
    // iRiS: quiet translucent choices on black, the accent marks the selected one
    // (the same pairing as the edit toolbar's committing action).
    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    implicitHeight: 32

    // Override the inherited family-aware bindings only while iRiS owns this
    // control. Restore them verbatim when the panel family changes at runtime.
    Binding { target: root; property: "colBackground"; value: ColorUtils.applyAlpha(IrisStyle.text, 0.08); when: root.iris; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colBackgroundHover"; value: ColorUtils.applyAlpha(IrisStyle.text, 0.14); when: root.iris; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colBackgroundActive"; value: ColorUtils.applyAlpha(IrisStyle.text, 0.2); when: root.iris; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colBackgroundToggled"; value: IrisStyle.accent; when: root.iris; restoreMode: Binding.RestoreBinding }
    Binding { target: root; property: "colBackgroundToggledHover"; value: Qt.lighter(IrisStyle.accent, 1.08); when: root.iris; restoreMode: Binding.RestoreBinding }
    StyledToolTip { text: root.buttonText }
}
