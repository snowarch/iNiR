import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    required property var preset
    property bool forceActive: false
    property bool isActive: forceActive || preset.id === ThemeService.currentTheme
    readonly property bool favoriteEnabled: preset.saved !== true
    readonly property bool isFavorite: favoriteEnabled && (Config.options?.appearance?.favoriteThemes ?? []).includes(preset.id)

    signal clicked()

    // Helper to safely get color from preset
    function getColor(key, fallback) {
        if (!preset.colors) return Appearance.m3colors[key] ?? fallback
        if (preset.colors === "custom") return Config.options?.appearance?.customTheme?.[key] ?? fallback
        return preset.colors[key] ?? fallback
    }

    function toggleFavorite() {
        let favs = Config.options?.appearance?.favoriteThemes ?? []
        if (root.isFavorite) {
            favs = favs.filter(t => t !== preset.id)
        } else {
            favs = [...favs, preset.id]
        }
        Config.setNestedValue("appearance.favoriteThemes", favs)
    }

    implicitHeight: 36

    // Card background
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: Appearance.rounding.small

        // Get primary color from THIS preset (not current theme)
        readonly property color presetPrimary: root.getColor("m3primary", "#6366f1")

        color: cardMouseArea.containsMouse
            ? Appearance.colors.colLayer2Hover
            : Appearance.colors.colLayer2

        border.width: root.isActive ? 1.5 : 0
        border.color: cardBg.presetPrimary

        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: 100 } }
    }

    // Content row
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 4
        spacing: 6

        // Color swatches - simple overlapping circles
        Row {
            spacing: -4

            Repeater {
                model: [
                    { key: "m3primary", fallback: "#6366f1" },
                    { key: "m3secondary", fallback: "#818cf8" },
                    { key: "m3background", fallback: "#0f0f23" }
                ]

                Rectangle {
                    required property var modelData
                    required property int index

                    width: 14
                    height: 14
                    radius: 7
                    color: root.getColor(modelData.key, modelData.fallback)
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.25)
                    z: 3 - index
                }
            }
        }

        MaterialSymbol {
            visible: root.preset.saved === true
            text: "bookmark"
            iconSize: 13
            color: cardBg.presetPrimary
        }

        // Theme name - clickable area for selecting theme
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                text: preset.name
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: root.isActive ? Font.DemiBold : Font.Normal
                color: root.isActive
                    ? cardBg.presetPrimary
                    : Appearance.colors.colOnLayer2
                elide: Text.ElideRight
            }

            MouseArea {
                id: cardMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clicked()
            }
        }

        // Favorite button - separate clickable area
        Rectangle {
            id: starButton
            width: 28
            height: 28
            radius: 14
            color: starMouseArea.containsMouse
                ? (root.isFavorite ? Appearance.colors.colLayer1Hover : Appearance.colors.colTertiaryContainer)
                : "transparent"
            visible: root.favoriteEnabled && (root.isFavorite || cardMouseArea.containsMouse || starMouseArea.containsMouse)

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "star"
                fill: root.isFavorite ? 1 : 0
                iconSize: 16
                color: root.isFavorite
                    ? Appearance.colors.colTertiary
                    : starMouseArea.containsMouse
                        ? Appearance.colors.colOnTertiaryContainer
                        : Appearance.colors.colSubtext
            }

            MouseArea {
                id: starMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleFavorite()
            }

            StyledToolTip {
                text: root.isFavorite ? Translation.tr("Remove from favorites") : Translation.tr("Add to favorites")
                visible: starMouseArea.containsMouse
            }
        }

        // Active check
        MaterialSymbol {
            visible: root.isActive && !starButton.visible
            text: "check"
            iconSize: 16
            color: cardBg.presetPrimary
        }
    }

    // Tooltip for theme description
    StyledToolTip {
        text: preset.description ?? ""
        visible: cardMouseArea.containsMouse && (preset.description ?? "").length > 0
        delay: 500
    }
}
