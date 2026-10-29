pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common

ColumnLayout {
    id: root

    property string icon: "tune"
    property string title: ""
    property string description: ""
    property string summary: ""
    property bool showSummary: root.options.length === 0
    // The page header already shows name/description; a card under it saying the page's name again was the first
    // thing every page repeated. Only a page that needs extra onboarding copy asks for it.
    property bool showIntro: false
    property string currentValue: ""
    property var options: []
    property var searchAliases: ({})

    signal selected(string value)

    function _normalizeSearchLabel(value): string {
        return String(value || "")
            .toLowerCase()
            .split(/[·›]/)
            .map(part => part.trim())
            .filter(part => part.length > 0)
            .pop() || ""
    }

    function resolveSearchSection(section): string {
        const label = _normalizeSearchLabel(section)
        if (!label.length)
            return ""

        const aliased = searchAliases?.[label]
        if (aliased !== undefined)
            return String(aliased)

        for (let i = 0; i < options.length; ++i) {
            const option = options[i] ?? ({})
            if (_normalizeSearchLabel(option.displayName) === label
                    || _normalizeSearchLabel(option.value) === label)
                return String(option.value ?? "")
        }
        return ""
    }

    function step(delta: int): void {
        const values = root.options.map(option => String(option?.value ?? ""))
        const next = values.indexOf(String(root.currentValue)) + delta
        if (next >= 0 && next < values.length)
            root.selected(values[next])
    }

    function activateSearchSection(section): bool {
        const value = resolveSearchSection(section)
        if (!value.length)
            return false
        root.selected(value)
        return true
    }

    function _findSettingsPage(): var {
        let item = root.parent
        while (item) {
            if (item.hasOwnProperty("settingsPageIndex")
                    && item.hasOwnProperty("settingsTaskNavigator"))
                return item
            item = item.parent
        }
        return null
    }

    Component.onCompleted: {
        const page = _findSettingsPage()
        if (page)
            page.settingsTaskNavigator = root
    }

    Component.onDestruction: {
        const page = _findSettingsPage()
        if (page && page.settingsTaskNavigator === root)
            page.settingsTaskNavigator = null
    }

    Layout.fillWidth: true
    spacing: 12

    Rectangle {
        visible: root.showIntro && (root.title.length > 0 || root.description.length > 0)
        Layout.fillWidth: true
        implicitHeight: visible ? introColumn.implicitHeight + (root.title.length > 0 ? 24 : 20) : 0
        radius: Appearance.rounding.normal
        color: Appearance.editorialEverywhere ? Appearance.editorial.ink : Appearance.colors.colLayer1
        border.width: Appearance.editorialEverywhere ? 1 : 0
        border.color: Appearance.editorialEverywhere ? Appearance.editorial.rule : Appearance.colors.colOutlineVariant


        // Full variant (icon + title + description) for pages that onboard;
        // compact variant (centered description + summary) when the page header
        // already carries the name and icon.
        ColumnLayout {
            id: introColumn
            anchors.fill: parent
            anchors.margins: root.title.length > 0 ? 12 : 10
            spacing: root.title.length > 0 ? 9 : 4

            RowLayout {
                Layout.fillWidth: true
                visible: root.title.length > 0
                spacing: 10

                Item {
                    Layout.preferredWidth: Appearance.cookieEverywhere ? 40 : 24
                    Layout.preferredHeight: Appearance.cookieEverywhere ? 40 : 24
                    Layout.alignment: Qt.AlignTop
                    visible: root.icon.length > 0

                    MaterialShape {
                        anchors.centerIn: parent
                        visible: Appearance.editorialEverywhere && Appearance.editorial.ornaments
                        implicitSize: 22
                        shape: MaterialShape.Shape.Flower
                        color: Appearance.editorial.paperOnInk
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !Appearance.cookieEverywhere
                            && !(Appearance.editorialEverywhere && Appearance.editorial.ornaments)
                        text: root.icon
                        iconSize: 22
                        color: Appearance.editorialEverywhere
                            ? Appearance.editorial.paperOnInk : Appearance.colors.colOnLayer1
                    }

                    MaterialCookie {
                        anchors.centerIn: parent
                        visible: Appearance.cookieEverywhere
                        implicitSize: 40
                        sides: 9
                        color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.icon
                            iconSize: 19
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        Layout.fillWidth: true
                        text: root.title
                        font.family: Appearance.editorialEverywhere ? Appearance.font.family.title : Appearance.font.family.main
                        font.pixelSize: Appearance.editorialEverywhere ? Appearance.font.pixelSize.hugeass : Appearance.font.pixelSize.normal
                        readonly property int titleWeight: Appearance.editorialEverywhere
                            ? Appearance.editorial.titleWeight : Font.DemiBold
                        font.weight: titleWeight
                        font.variableAxes: Object.assign({}, Appearance.font.variableAxes.main, { "wght": titleWeight })
                        font.letterSpacing: Appearance.editorialEverywhere ? Appearance.editorial.titleTracking : 0
                        color: Appearance.editorialEverywhere ? Appearance.editorial.paperOnInk : Appearance.colors.colOnLayer1
                        wrapMode: Text.Wrap
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.description.length > 0
                        text: root.description
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.editorialEverywhere ? Appearance.editorial.paperOnInk : Appearance.colors.colOnLayer1
                        opacity: Appearance.editorialEverywhere ? 1 : 0.82
                        wrapMode: Text.Wrap
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.title.length === 0 && root.description.length > 0
                text: root.description
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.editorialEverywhere ? Appearance.editorial.paperOnInk : Appearance.colors.colOnLayer1
                opacity: Appearance.editorialEverywhere ? 1 : 0.86
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.showSummary && root.summary.length > 0
                text: root.summary
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Medium
                color: Appearance.editorialEverywhere ? Appearance.editorial.paperOnInk : Appearance.colors.colOnLayer1
                opacity: Appearance.editorialEverywhere ? 1 : 0.72
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
            }
        }
    }

    // The page's parts as M3 secondary tabs: they read as places on this page, not as values to pick, which a
    // button group (what was here) made them look like.
    Item {
        id: tabs
        visible: root.options.length > 0
        Layout.fillWidth: true
        implicitHeight: 48

        Flickable {
            id: tabFlick
            anchors.fill: parent
            contentWidth: tabRow.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: contentWidth > width
            // One Tab stop for the strip, on the open tab; ← → open the neighbour (M3 tabs, a stop per tab before).
            activeFocusOnTab: true
            Accessible.role: Accessible.PageTabList
            Keys.onLeftPressed: root.step(-1)
            Keys.onRightPressed: root.step(1)

            Row {
                id: tabRow
                height: parent.height

                Repeater {
                    id: tabRepeater
                    model: root.options
                    delegate: RippleButton {
                        id: tab
                        required property var modelData
                        required property int index
                        readonly property bool current: String(modelData.value) === String(root.currentValue)
                        height: tabRow.height
                        implicitWidth: tabLabel.implicitWidth + 32
                        buttonRadius: Appearance.rounding.verysmall
                        colBackground: "transparent"
                        colBackgroundHover: SettingsMaterialPreset.tileHoverColor
                        colRipple: SettingsMaterialPreset.tilePressColor
                        pressScaleEnabled: false
                        focusPolicy: Qt.NoFocus
                        focusRingInward: true
                        focusRingShown: tabFlick.activeFocus && tab.current
                        onClicked: root.selected(modelData.value)
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.displayName

                        contentItem: StyledText {
                            id: tabLabel
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: tab.modelData.displayName
                            font.pixelSize: Math.round(14 * Appearance.fontSizeScale)
                            font.weight: Font.Medium
                            color: tab.current ? SettingsMaterialPreset.labelColor : SettingsMaterialPreset.supportingColor
                            opacity: tab.modelData.dimmed === true && !tab.current ? 0.6 : 1
                        }
                    }
                }
            }

            Rectangle {
                id: indicator
                readonly property Item target: {
                    for (let i = 0; i < tabRepeater.count; ++i) {
                        const t = tabRepeater.itemAt(i)
                        if (t && t.current)
                            return t
                    }
                    return null
                }
                visible: target !== null
                y: tabRow.height - height
                height: 3
                topLeftRadius: 3
                topRightRadius: 3
                x: target ? target.x + 16 : 0
                width: target ? target.width - 32 : 0
                color: SettingsMaterialPreset.subheaderColor
                Behavior on x { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve } }
                Behavior on width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve } }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Appearance.colors.colOutlineVariant
            z: -1
        }
    }
}
