pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// The nine Global Styles as cards, each with a small picture of its character drawn in the scheme's own colours
// (only Appearance knows the style in use, so the others are sketched here, not rendered).
Item {
    id: root

    property string currentValue: "material"
    signal selected(string value)

    readonly property var styles: [
        { value: "material", name: Translation.tr("Material"), line: Translation.tr("Tonal, soft, expressive") },
        { value: "cards", name: Translation.tr("Cards"), line: Translation.tr("Material in separate cards") },
        { value: "aurora", name: Translation.tr("Aurora"), line: Translation.tr("Frosted glass panels") },
        { value: "inir", name: Translation.tr("Inir"), line: Translation.tr("Terminal calm, lines and type") },
        { value: "angel", name: Translation.tr("Angel"), line: Translation.tr("Glass, offset shadows, gold") },
        { value: "regalia", name: Translation.tr("Regalia"), line: Translation.tr("Dark, ivory and gold") },
        { value: "zzz", name: Translation.tr("ZZZ"), line: Translation.tr("Poster plates, cut corners") },
        { value: "cookie", name: Translation.tr("Cookie Shapes"), line: Translation.tr("Expressive at its loudest") },
        { value: "editorial", name: Translation.tr("Editorial"), line: Translation.tr("Paper, ink and strong type") }
    ]
    readonly property real gap: 10
    readonly property int columns: Math.max(2, Math.min(4, Math.floor((root.width + root.gap) / (190 + root.gap))))
    readonly property real cardWidth: Math.floor((root.width - root.gap * (root.columns - 1)) / root.columns)

    readonly property var m: Appearance.m3colors
    readonly property bool dark: Appearance.m3colors.darkmode

    Layout.fillWidth: true
    implicitHeight: grid.implicitHeight

    property int settingsSearchOptionId: -1
    function focusFromSettingsSearch() { root.forceActiveFocus() }
    Component.onCompleted: {
        if (typeof SettingsSearchRegistry === "undefined" || !SettingsSearchRegistry.dynamicRegistrationEnabled)
            return
        let page = null
        for (let p = root.parent; p && !page; p = p.parent)
            if (p.hasOwnProperty("settingsPageIndex")) page = p
        const names = root.styles.map(style => String(style.name).toLowerCase())
        root.settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: page?.settingsPageIndex ?? -1,
            pageName: page?.settingsPageName ?? "",
            section: Translation.tr("Global Style"),
            label: Translation.tr("Global Style"),
            description: names.join(", "),
            keywords: names
        })
    }
    Component.onDestruction: if (typeof SettingsSearchRegistry !== "undefined") SettingsSearchRegistry.unregisterControl(root)

    Grid {
        id: grid
        columns: root.columns
        spacing: root.gap

        Repeater {
            model: root.styles
            delegate: RippleButton {
                id: card
                required property var modelData
                readonly property bool chosen: root.currentValue === card.modelData.value
                width: root.cardWidth
                height: 96 + 50
                buttonRadius: Appearance.rounding.normal
                colBackground: card.chosen ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: card.chosen ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: card.chosen ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colLayer2Active
                Accessible.name: card.modelData.name
                onClicked: root.selected(card.modelData.value)

                contentItem: Item {
                    Item {
                        id: picture
                        x: 6
                        y: 6
                        width: card.width - 12
                        height: 92
                        Loader {
                            anchors.fill: parent
                            sourceComponent: {
                                switch (card.modelData.value) {
                                case "cards": return cardsPicture
                                case "aurora": return auroraPicture
                                case "inir": return inirPicture
                                case "angel": return angelPicture
                                case "regalia": return regaliaPicture
                                case "zzz": return zzzPicture
                                case "cookie": return cookiePicture
                                case "editorial": return editorialPicture
                                default: return materialPicture
                                }
                            }
                        }
                    }
                    Rectangle {
                        anchors { right: picture.right; top: picture.top; margins: 6 }
                        width: 20
                        height: 20
                        radius: 10
                        visible: card.chosen
                        color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "check"
                            iconSize: 14
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                    ColumnLayout {
                        anchors { left: parent.left; right: parent.right; top: picture.bottom; leftMargin: 12; rightMargin: 12; topMargin: 8 }
                        spacing: 1
                        StyledText {
                            Layout.fillWidth: true
                            text: card.modelData.name
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: card.chosen ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: card.modelData.line
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: card.chosen ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                            opacity: card.chosen ? 0.8 : 1
                        }
                    }
                }
            }
        }
    }

    // The desktop every picture sits on: the scheme's two containers, like a wallpaper it came from.
    component Desk: Rectangle {
        radius: Appearance.rounding.normal - 4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.m.m3primaryContainer }
            GradientStop { position: 1; color: root.m.m3tertiaryContainer }
        }
    }
    component Line: Rectangle {
        property real share: 0.5
        height: 4
        radius: 2
        width: parent ? parent.width * share : 0
    }

    Component {
        id: materialPicture
        Desk {
            Rectangle {
                anchors { fill: parent; margins: 12 }
                radius: 16
                color: root.m.m3surfaceContainerLow
                Column {
                    x: 12; y: 12; width: parent.width - 24; spacing: 6
                    Line { share: 0.55; color: root.m.m3onSurface; opacity: 0.85 }
                    Line { share: 0.35; color: root.m.m3onSurfaceVariant; opacity: 0.6 }
                }
                Rectangle { x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; width: 40; height: 16; radius: 8; color: root.m.m3primary }
                Rectangle {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                    width: 28; height: 16; radius: 8; color: root.m.m3primary
                    Rectangle { x: parent.width - 14; y: 2; width: 12; height: 12; radius: 6; color: root.m.m3onPrimary }
                }
            }
        }
    }
    Component {
        id: cardsPicture
        Desk {
            Row {
                anchors { fill: parent; margins: 12 }
                spacing: 6
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        required property int index
                        width: (parent.width - 6) / 2
                        height: parent.height
                        radius: 12
                        color: root.m.m3surfaceContainer
                        Column {
                            x: 9; y: 10; width: parent.width - 18; spacing: 6
                            Line { share: index === 0 ? 0.7 : 0.5; color: root.m.m3onSurface; opacity: 0.85 }
                            Line { share: 0.4; color: root.m.m3onSurfaceVariant; opacity: 0.6 }
                        }
                        Rectangle { x: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 9; width: 24; height: 12; radius: 6; color: index === 0 ? root.m.m3primary : root.m.m3secondaryContainer }
                    }
                }
            }
        }
    }
    Component {
        id: auroraPicture
        Desk {
            clip: true
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 24 }
                Rectangle { x: parent.width * 0.55; y: 4; width: 64; height: 64; radius: 32; color: root.m.m3primary; opacity: 0.7 }
                Rectangle { x: 16; y: parent.height - 50; width: 48; height: 48; radius: 24; color: root.m.m3tertiary; opacity: 0.6 }
            }
            Rectangle {
                anchors { fill: parent; margins: 12 }
                radius: 14
                color: Qt.rgba(1, 1, 1, root.dark ? 0.10 : 0.35)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, root.dark ? 0.28 : 0.6)
                Column {
                    x: 12; y: 12; width: parent.width - 24; spacing: 6
                    Line { share: 0.55; color: root.m.m3onSurface; opacity: 0.9 }
                    Line { share: 0.35; color: root.m.m3onSurface; opacity: 0.55 }
                }
                Rectangle { x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; width: 40; height: 16; radius: 8; color: Qt.rgba(1, 1, 1, 0.22); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35) }
            }
        }
    }
    Component {
        id: inirPicture
        Rectangle {
            radius: 3
            color: root.m.m3background
            border.width: 1
            border.color: root.m.m3outlineVariant
            Rectangle {
                anchors { fill: parent; margins: 10 }
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: root.m.m3outline
                Column {
                    x: 8; y: 8; spacing: 3
                    Repeater {
                        model: ["~ inir status", "  shell  ok", "  bar    on"]
                        delegate: Text {
                            required property string modelData
                            required property int index
                            text: modelData
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: 10
                            color: index === 0 ? root.m.m3primary : root.m.m3onSurfaceVariant
                        }
                    }
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 } height: 1; color: root.m.m3outlineVariant }
            }
        }
    }
    Component {
        id: angelPicture
        Desk {
            Rectangle { x: 18; y: 18; width: parent.width - 30; height: parent.height - 30; radius: 6; color: "#d9b45a"; opacity: 0.55 }
            Rectangle {
                id: angelPlate
                x: 12; y: 12; width: parent.width - 30; height: parent.height - 30
                radius: 6
                color: ColorUtils.applyAlpha(root.m.m3surfaceContainer, 0.82)
                Rectangle { width: parent.width * 0.6; height: 1.5; color: "#e8c56b" }
                Rectangle { width: 1.5; height: parent.height * 0.6; color: "#e8c56b" }
                Column {
                    x: 12; y: 12; width: parent.width - 24; spacing: 6
                    Line { share: 0.55; color: root.m.m3onSurface; opacity: 0.9 }
                    Line { share: 0.35; color: "#e8c56b"; opacity: 0.8 }
                }
            }
        }
    }
    Component {
        id: regaliaPicture
        Rectangle {
            radius: 6
            color: "#120f0c"
            Rectangle {
                anchors { fill: parent; margins: 12 }
                radius: 4
                color: "#1c1814"
                border.width: 1
                border.color: "#3a3127"
                Column {
                    x: 12; y: 12; width: parent.width - 24; spacing: 7
                    Line { share: 0.5; color: "#ece3cf" }
                    Rectangle { width: parent.width; height: 1; color: "#b9965b" }
                    Line { share: 0.3; color: "#a89a82"; opacity: 0.8 }
                }
                Rectangle { anchors { right: parent.right; bottom: parent.bottom; margins: 10 } width: 34; height: 14; radius: 3; color: "#5a1f22"; border.width: 1; border.color: "#b9965b" }
            }
        }
    }
    Component {
        id: zzzPicture
        Desk {
            Rectangle {
                anchors { fill: parent; margins: 12 }
                color: "#0d0d0d"
                clip: true
                Column {
                    x: 12; y: 12; width: parent.width - 24; spacing: 6
                    Line { share: 0.6; radius: 0; color: "#f2f2f2" }
                    Line { share: 0.35; radius: 0; color: "#8a8a8a" }
                }
                // the cut corner
                Rectangle { x: parent.width - 11; y: -11; width: 22; height: 22; rotation: 45; color: root.m.m3tertiaryContainer }
                Rectangle {
                    x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                    width: 44; height: 16; rotation: -4; color: root.m.m3primary
                    Text { anchors.centerIn: parent; text: "ZZZ"; font.family: "Oxanium"; font.pixelSize: 10; font.weight: Font.Black; color: root.m.m3onPrimary }
                }
            }
        }
    }
    Component {
        id: cookiePicture
        Desk {
            Rectangle {
                anchors { fill: parent; margins: 12 }
                radius: 26
                color: root.m.m3surfaceContainerLow
                MaterialShape {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                    implicitSize: 46
                    shape: MaterialShape.Shape.Cookie9Sided
                    color: root.m.m3primary
                }
                Column {
                    x: 14; y: 14; width: parent.width - 80; spacing: 6
                    Line { share: 0.8; color: root.m.m3onSurface; opacity: 0.85 }
                    Line { share: 0.5; color: root.m.m3onSurfaceVariant; opacity: 0.6 }
                }
                Rectangle { x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; width: 30; height: 16; radius: 8; color: root.m.m3tertiaryContainer }
            }
        }
    }
    Component {
        id: editorialPicture
        Rectangle {
            radius: 4
            color: root.dark ? "#1d1b18" : "#f3eee4"
            readonly property color ink: root.dark ? "#ece6da" : "#1f1c18"
            Text {
                x: 12; y: 6
                text: "Aa"
                font.family: Appearance.editorial.serifFamily
                font.pixelSize: 34
                font.weight: Font.DemiBold
                color: parent.ink
            }
            Column {
                x: 66; y: 16; width: parent.width - 78; spacing: 5
                Line { share: 0.9; height: 2; radius: 0; color: parent.parent.ink; opacity: 0.85 }
                Line { share: 0.7; height: 2; radius: 0; color: parent.parent.ink; opacity: 0.5 }
                Line { share: 0.8; height: 2; radius: 0; color: parent.parent.ink; opacity: 0.5 }
            }
            Rectangle { x: 12; y: 58; width: parent.width - 24; height: 1; color: root.m.m3primary }
            Line { x: 12; y: 68; width: 60; height: 2; radius: 0; color: parent.ink; opacity: 0.4 }
        }
    }
}
