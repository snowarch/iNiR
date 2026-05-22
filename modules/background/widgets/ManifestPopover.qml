pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property string configEntryName
    required property var manifestKeys
    property var readConfigKey: null

    implicitWidth: _col.implicitWidth
    implicitHeight: _col.implicitHeight

    Column {
        id: _col
        spacing: 4

        Repeater {
            model: root.manifestKeys

            Item {
                id: keyDelegate
                required property var modelData
                readonly property string cfgKey: modelData.key
                readonly property var spec: modelData.spec
                readonly property string cfgType: spec?.type ?? "bool"
                readonly property string label: spec?.label ?? cfgKey
                readonly property var currentVal: root.readConfigKey ? root.readConfigKey(cfgKey) : spec?.["default"]

                width: _content.implicitWidth
                height: _content.implicitHeight

                Row {
                    id: _content
                    spacing: 4

                    // Bool: toggle button
                    RippleButton {
                        visible: keyDelegate.cfgType === "bool"
                        width: visible ? Math.max(100, _boolLabel.implicitWidth + 16) : 0; height: 28
                        buttonRadius: Appearance.rounding.small
                        toggled: Boolean(keyDelegate.currentVal)
                        colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        downAction: () => Config.setNestedValue("background.widgets." + root.configEntryName + "." + keyDelegate.cfgKey, !Boolean(keyDelegate.currentVal))
                        contentItem: StyledText {
                            id: _boolLabel
                            anchors.centerIn: parent
                            text: keyDelegate.label
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    // Numeric: label + -/value/+
                    StyledText {
                        visible: keyDelegate.cfgType !== "bool"
                        anchors.verticalCenter: parent.verticalCenter
                        text: keyDelegate.label
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    RippleButton {
                        visible: keyDelegate.cfgType !== "bool"
                        width: visible ? 24 : 0; height: 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.06)
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        downAction: () => {
                            const step = keyDelegate.spec?.step ?? 1;
                            const min = keyDelegate.spec?.min ?? -Infinity;
                            Config.setNestedValue("background.widgets." + root.configEntryName + "." + keyDelegate.cfgKey,
                                Math.max(min, Number(keyDelegate.currentVal ?? 0) - step));
                        }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "remove"; iconSize: 14; color: Appearance.colors.colOnLayer2 }
                    }
                    StyledText {
                        visible: keyDelegate.cfgType !== "bool"
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(keyDelegate.currentVal ?? keyDelegate.spec?.["default"] ?? 0)
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.numbers
                    }
                    RippleButton {
                        visible: keyDelegate.cfgType !== "bool"
                        width: visible ? 24 : 0; height: 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.06)
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        downAction: () => {
                            const step = keyDelegate.spec?.step ?? 1;
                            const max = keyDelegate.spec?.max ?? Infinity;
                            Config.setNestedValue("background.widgets." + root.configEntryName + "." + keyDelegate.cfgKey,
                                Math.min(max, Number(keyDelegate.currentVal ?? 0) + step));
                        }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "add"; iconSize: 14; color: Appearance.colors.colOnLayer2 }
                    }
                }
            }
        }
    }
}
