import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * ElementTooltip - Detailed tooltip content for periodic table elements
 * Shows full element name, atomic mass, electron configuration, and category
 * Requirements: 5.1
 */
Item {
    id: root
    required property var element

    // Category display names - computed dynamically to handle Translation availability
    function getCategoryName(type) {
        if (!type) return ""
        const names = {
            "metal": Translation.tr("Metal"),
            "nonmetal": Translation.tr("Nonmetal"),
            "noblegas": Translation.tr("Noble Gas"),
            "lanthanum": Translation.tr("Lanthanide"),
            "actinium": Translation.tr("Actinide"),
            "empty": ""
        }
        return names[type] ?? type
    }

    // Electron configurations for common elements
    readonly property var electronConfigs: ({
        1: "1s¹",
        2: "1s²",
        3: "[He] 2s¹",
        4: "[He] 2s²",
        5: "[He] 2s² 2p¹",
        6: "[He] 2s² 2p²",
        7: "[He] 2s² 2p³",
        8: "[He] 2s² 2p⁴",
        9: "[He] 2s² 2p⁵",
        10: "[He] 2s² 2p⁶",
        11: "[Ne] 3s¹",
        12: "[Ne] 3s²",
        13: "[Ne] 3s² 3p¹",
        14: "[Ne] 3s² 3p²",
        15: "[Ne] 3s² 3p³",
        16: "[Ne] 3s² 3p⁴",
        17: "[Ne] 3s² 3p⁵",
        18: "[Ne] 3s² 3p⁶",
        19: "[Ar] 4s¹",
        20: "[Ar] 4s²",
        26: "[Ar] 3d⁶ 4s²",
        29: "[Ar] 3d¹⁰ 4s¹",
        47: "[Kr] 4d¹⁰ 5s¹",
        79: "[Xe] 4f¹⁴ 5d¹⁰ 6s¹"
    })

    implicitWidth: contentLayout.implicitWidth + 2 * Appearance.sizes.spacingSmall
    implicitHeight: contentLayout.implicitHeight + 2 * Appearance.sizes.spacingSmall

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colTooltip
        radius: Appearance.rounding.small

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    ColumnLayout {
        id: contentLayout
        anchors {
            fill: parent
            margins: Appearance.sizes.spacingSmall
        }
        spacing: Appearance.sizes.spacingSmall / 2

        // Element name and symbol header
        RowLayout {
            spacing: Appearance.sizes.spacingSmall

            StyledText {
                text: root.element.name
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnTooltip
            }

            StyledText {
                text: "(" + root.element.symbol + ")"
                font.pixelSize: Appearance.font.pixelSize.small
                color: ColorUtils.transparentize(Appearance.colors.colOnTooltip, 0.3)
            }
        }

        // Separator line
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: ColorUtils.transparentize(Appearance.colors.colOnTooltip, 0.8)
        }

        // Atomic number
        RowLayout {
            spacing: Appearance.sizes.spacingSmall / 2

            StyledText {
                text: Translation.tr("Atomic Number") + ":"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.transparentize(Appearance.colors.colOnTooltip, 0.3)
            }

            StyledText {
                text: root.element.number.toString()
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnTooltip
            }
        }

        // Atomic mass
        RowLayout {
            spacing: Appearance.sizes.spacingSmall / 2

            StyledText {
                text: Translation.tr("Atomic Mass") + ":"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.transparentize(Appearance.colors.colOnTooltip, 0.3)
            }

            StyledText {
                text: root.element.weight.toString() + " u"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnTooltip
            }
        }

        // Electron configuration (if available)
        RowLayout {
            visible: root.electronConfigs[root.element.number] !== undefined
            spacing: Appearance.sizes.spacingSmall / 2

            StyledText {
                text: Translation.tr("Electron Config") + ":"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.transparentize(Appearance.colors.colOnTooltip, 0.3)
            }

            StyledText {
                text: root.electronConfigs[root.element.number] ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnTooltip
            }
        }

        // Category
        RowLayout {
            spacing: Appearance.sizes.spacingSmall / 2

            StyledText {
                text: Translation.tr("Category") + ":"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.transparentize(Appearance.colors.colOnTooltip, 0.3)
            }

            StyledText {
                text: root.getCategoryName(root.element?.type)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnTooltip
            }
        }
    }
}
