pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.background.widgets
import qs.modules.iris.style
import qs.modules.iris.components

ColumnLayout {
    id: root

    readonly property real d: IrisStyle.density
    readonly property string outputName: GlobalStates.focusedScreen?.name ?? ""
    // Widgets without an iRiS face that are on this screen anyway, listed after the set so they count and can be taken away.
    readonly property var entries: {
        Config.revision
        return IrisFaceData.galleryEntries.concat(IrisFaceData.otherEntries.filter(entry => root.isOn(entry.key)))
    }
    readonly property int placed: {
        Config.revision
        return root.entries.filter(entry => root.isOn(entry.key)).length
    }

    function isOn(key: string): bool {
        Config.revision
        return DesktopWidgetLayout.enabled(root.outputName, key, Config.getNestedValue("background.widgets." + key + ".enable", false))
    }

    readonly property real longestWord: {
        nameMetrics.font
        let widest = 0
        for (const entry of root.entries)
            for (const word of String(entry.label ?? "").split(/\s+/))
                widest = Math.max(widest, nameMetrics.advanceWidth(word))
        return widest
    }
    FontMetrics { id: nameMetrics; font.family: IrisStyle.fontRead; font.pixelSize: IrisStyle.typeMeta; font.letterSpacing: IrisStyle.tracking(IrisStyle.typeMeta) }

    spacing: Math.round(12 * root.d)

    GridLayout {
        id: grid
        Layout.fillWidth: true
        // At least as wide as the longest word of any name: a name wraps between words, never inside one.
        readonly property real tile: Math.max(Math.round(76 * root.d), Math.ceil(root.longestWord) + Math.round(8 * root.d))
        columns: Math.max(3, Math.floor((width + columnSpacing) / (tile + columnSpacing)))
        columnSpacing: Math.round(6 * root.d)
        rowSpacing: Math.round(10 * root.d)

        Repeater {
            model: root.entries

            Item {
                id: entry
                required property var modelData
                readonly property bool on: { Config.revision; return root.isOn(entry.modelData.key) }
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: icon.height + name.implicitHeight + Math.round(8 * root.d)

                Rectangle {
                    id: icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(46 * root.d)
                    height: width
                    radius: IrisStyle.iconRadius(width)
                    color: icon.skinned ? "transparent" : entry.on ? entry.modelData.tint : hover.hovered ? IrisStyle.fillHover : IrisStyle.fill
                    scale: icon.skinned ? 1 : tap.pressed ? IrisStyle.pressScale(0.92) : hover.hovered ? 1.04 : 1
                    // A Design's control key (IrisDesign part `controlTile`) draws it, on or off, as it draws the Control
                    // Center's; its own mark of being on replaces the badge.
                    readonly property bool skinned: iconSkin.active
                    readonly property bool hovered: hover.hovered
                    readonly property bool down: tap.pressed
                    readonly property bool visualFocus: false
                    readonly property var skinData: ({ shape: "disc", control: ({ lit: entry.on, ready: true, glyph: entry.modelData.glyph,
                        label: entry.modelData.label, tint: entry.modelData.tint }) })
                    IrisSkin { id: iconSkin; part: "controlTile"; host: icon }
                    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

                    MaterialSymbol {
                        visible: !icon.skinned
                        anchors.centerIn: parent
                        text: entry.modelData.glyph
                        fill: 1
                        iconSize: Math.round(22 * root.d)
                        color: entry.on ? IrisStyle.onTint : IrisStyle.textSecondary
                    }
                    Rectangle {
                        visible: !icon.skinned
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: -Math.round(5 * root.d)
                        width: Math.round(18 * root.d)
                        height: width
                        radius: IrisStyle.capsule(width)
                        color: entry.on ? IrisStyle.surfaceHighest : IrisStyle.accent
                        border.width: 1
                        border.color: IrisStyle.surface
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: entry.on ? "remove" : "add"
                            iconSize: Math.round(13 * root.d)
                            font.weight: IrisStyle.weight(Font.Bold)
                            color: entry.on ? IrisStyle.text : IrisStyle.inkOnAccent
                        }
                    }
                }
                IrisText {
                    id: name
                    anchors.top: icon.bottom
                    anchors.topMargin: Math.round(6 * root.d)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: entry.modelData.label
                    color: entry.on ? IrisStyle.text : IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeMeta
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: tap; onTapped: DesktopWidgetLayout.setGloballyEnabled(entry.modelData.key, !entry.on) }
                Accessible.role: Accessible.CheckBox
                Accessible.name: entry.modelData.label
                Accessible.checked: entry.on
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(10 * root.d)

        IrisText {
            Layout.fillWidth: true
            text: root.placed === 1 ? Translation.tr("1 widget on this screen") : Translation.tr("%1 widgets on this screen").arg(root.placed)
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeMeta
        }
        IrisButton {
            implicitHeight: Math.round(30 * root.d)
            implicitWidth: arrangeRow.implicitWidth + Math.round(24 * root.d)
            onClicked: {
                GlobalStates.settingsOverlayOpen = false
                GlobalStates.setWidgetEditMode(true)
            }
            Accessible.name: Translation.tr("Arrange on the desktop")
            RowLayout {
                id: arrangeRow
                anchors.centerIn: parent
                spacing: Math.round(6 * root.d)
                MaterialSymbol { text: "open_with"; iconSize: Math.round(15 * root.d); color: IrisStyle.text }
                IrisText { text: Translation.tr("Arrange on the desktop"); font.pixelSize: IrisStyle.typeLabel; font.weight: IrisStyle.weight(Font.DemiBold) }
            }
        }
    }
}
