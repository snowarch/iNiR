pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Arrange settings — pick & place editor for the settings nav.
 *
 * Interaction model (no fragile drag, no arrow spam): tap a page chip or
 * a group handle to LIFT it; every valid insertion point lights up as an
 * ArrangeDropSlot; tap one to place, tap the lifted thing again (or the
 * banner) to cancel. Groups are cards; pages are ArrangeChips flowing
 * inside them.
 *
 * Persistence: settingsUi.categories as a JSON string ("" = defaults;
 * `property var` inside JsonObject crashes the VME). Every mutation
 * writes a full snapshot; SettingsPageRegistry sanitizes on read so no
 * page can ever be lost — orphans land in a trailing "More" group.
 * Components + method: inir-settings-ui skill.
 */
ContentPage {
    id: root
    settingsPageIndex: 20
    settingsPageName: Translation.tr("Arrange")

    // lifted: null | { type: "page", ci, pi, pageIdx } | { type: "group", index }
    property var lifted: null
    // which group's name is being edited inline (-1 = none)
    property int editingGroup: -1
    readonly property bool liftActive: lifted !== null
    readonly property bool liftIsPage: liftActive && lifted.type === "page"
    readonly property bool liftIsGroup: liftActive && lifted.type === "group"

    function _snapshot(): var {
        return ({
            groups: SettingsPageRegistry.categories.map(c => ({ label: c.label, pages: c.pages.slice() })),
            hidden: SettingsPageRegistry.hiddenPages.slice()
        })
    }
    function _save(arr): void {
        Config.setNestedValue("settingsUi.categories", JSON.stringify(arr))
        root.lifted = null
    }
    // lifted page may come from a group (ci >= 0) or from the hidden zone (ci === -1)
    function _takeLifted(arr): var {
        const { ci, pi } = root.lifted
        if (ci === -1) return arr.hidden.splice(pi, 1)[0]
        return arr.groups[ci]?.pages.splice(pi, 1)[0]
    }
    function placePage(targetCi: int, insertPos: int): void {
        if (!root.liftIsPage) return
        const a = _snapshot()
        const page = _takeLifted(a)
        if (page === undefined || !a.groups[targetCi]) { root.lifted = null; return }
        let pos = insertPos
        if (root.lifted.ci === targetCi && insertPos > root.lifted.pi) pos--
        a.groups[targetCi].pages.splice(Math.max(0, Math.min(pos, a.groups[targetCi].pages.length)), 0, page)
        _save(a)
    }
    function hidePage(): void {
        if (!root.liftIsPage) return
        const a = _snapshot()
        const page = _takeLifted(a)
        if (page === undefined) { root.lifted = null; return }
        if (!a.hidden.includes(page)) a.hidden.push(page)
        _save(a)
    }
    function placeGroup(insertPos: int): void {
        if (!root.liftIsGroup) return
        const a = _snapshot()
        const from = root.lifted.index
        if (!a.groups[from]) { root.lifted = null; return }
        const g = a.groups.splice(from, 1)[0]
        let pos = insertPos
        if (insertPos > from) pos--
        a.groups.splice(Math.max(0, Math.min(pos, a.groups.length)), 0, g)
        _save(a)
    }
    function renameCategory(i: int, label: string): void {
        const a = _snapshot()
        if (!a.groups[i] || label.trim().length === 0) return
        a.groups[i].label = label.trim()
        _save(a)
    }
    function removeCategory(i: int): void {
        const a = _snapshot()
        if (!a.groups[i] || a.groups[i].pages.length > 0) return
        a.groups.splice(i, 1)
        _save(a)
    }
    function addCategory(): void {
        const a = _snapshot()
        a.groups.push({ label: Translation.tr("New group"), pages: [] })
        _save(a)
    }

    SettingsCardSection {
        expanded: true
        icon: "swap_vert"
        title: Translation.tr("Arrange settings")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Tap a page or a group handle to pick it up, then tap where it should go. Search always finds everything, whatever you do here.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }

            // Floating status banner while something is lifted
            Rectangle {
                Layout.fillWidth: true
                visible: root.liftActive
                implicitHeight: bannerRow.implicitHeight + 16
                radius: Appearance.rounding.small
                color: Appearance.colors.colPrimaryContainer

                RowLayout {
                    id: bannerRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    MaterialSymbol {
                        text: root.liftIsGroup ? "folder" : "description"
                        iconSize: 20
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (root.liftIsGroup)
                                return Translation.tr("Moving group “%1” — tap a slot between groups").arg(SettingsPageRegistry.categories[root.lifted.index]?.label ?? "")
                            const p = SettingsPageRegistry.pages[root.lifted?.pageIdx ?? -1]
                            return Translation.tr("Moving “%1” — tap a slot inside any group").arg(p?.name ?? "")
                        }
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        elide: Text.ElideRight
                    }
                    RippleButtonWithIcon {
                        materialIcon: "close"
                        mainText: Translation.tr("Cancel")
                        onClicked: root.lifted = null
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 5
                RippleButtonWithIcon {
                    materialIcon: "create_new_folder"
                    mainText: Translation.tr("Add group")
                    onClicked: root.addCategory()
                }
                RippleButtonWithIcon {
                    materialIcon: "restart_alt"
                    mainText: Translation.tr("Reset arrangement")
                    onClicked: {
                        root.lifted = null
                        Config.setNestedValue("settingsUi.categories", "")
                    }
                }
            }
        }

        // Group cards with drop bars between them
        Repeater {
            model: SettingsPageRegistry.categories.length + 1
            delegate: ColumnLayout {
                id: slotCol
                required property int index
                Layout.fillWidth: true
                spacing: 0

                // Insertion bar for group moves (before group `index`)
                ArrangeDropSlot {
                    Layout.fillWidth: true
                    compact: false
                    active: root.liftIsGroup && root.lifted.index !== slotCol.index && root.lifted.index !== slotCol.index - 1
                    onPlaced: root.placeGroup(slotCol.index)
                }

                SettingsGroup {
                    id: catGroup
                    visible: slotCol.index < SettingsPageRegistry.categories.length
                    readonly property var cat: SettingsPageRegistry.categories[slotCol.index] ?? ({ label: "", pages: [] })
                    readonly property bool groupLifted: root.liftIsGroup && root.lifted.index === slotCol.index

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        readonly property bool editing: root.editingGroup === slotCol.index

                        // The group's grab handle — tap to lift the whole group
                        ArrangeChip {
                            icon: "drag_indicator"
                            lifted: catGroup.groupLifted
                            dimmed: root.liftActive && !catGroup.groupLifted
                            onTapped: {
                                root.lifted = catGroup.groupLifted ? null : ({ type: "group", index: slotCol.index })
                            }
                        }

                        // Display mode: plain title + subtle count; pencil to edit
                        StyledText {
                            visible: !parent.editing
                            text: catGroup.cat.label
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                        StyledText {
                            visible: !parent.editing
                            text: catGroup.cat.pages.length === 1
                                ? Translation.tr("1 page")
                                : Translation.tr("%1 pages").arg(catGroup.cat.pages.length)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        // Edit mode: compact field, confirmed with Enter or the check
                        MaterialTextField {
                            id: renameField
                            visible: parent.editing
                            Layout.preferredWidth: 240
                            text: catGroup.cat.label
                            onVisibleChanged: if (visible) { text = catGroup.cat.label; forceActiveFocus() }
                            onAccepted: {
                                root.renameCategory(slotCol.index, text)
                                root.editingGroup = -1
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RippleButtonWithIcon {
                            materialIcon: parent.editing ? "check" : "edit"
                            visible: !root.liftActive
                            onClicked: {
                                if (parent.editing) {
                                    root.renameCategory(slotCol.index, renameField.text)
                                    root.editingGroup = -1
                                } else {
                                    root.editingGroup = slotCol.index
                                }
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "delete"
                            visible: catGroup.cat.pages.length === 0 && !root.liftActive && !parent.editing
                            onClicked: root.removeCategory(slotCol.index)
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: catGroup.cat.pages.length + 1
                            delegate: Row {
                                id: chipCell
                                required property int index
                                readonly property bool isTail: chipCell.index >= catGroup.cat.pages.length
                                readonly property int pageIdx: isTail ? -1 : (catGroup.cat.pages[chipCell.index] ?? -1)
                                readonly property var page: SettingsPageRegistry.pages[chipCell.pageIdx] ?? null
                                readonly property bool chipLifted: root.liftIsPage
                                    && root.lifted.ci === slotCol.index && root.lifted.pi === chipCell.index
                                spacing: 6

                                // Insertion tile before this chip (and as the tail slot)
                                ArrangeDropSlot {
                                    compact: true
                                    active: root.liftIsPage
                                        && !(root.lifted.ci === slotCol.index
                                             && (root.lifted.pi === chipCell.index || root.lifted.pi === chipCell.index - 1))
                                    onPlaced: root.placePage(slotCol.index, chipCell.index)
                                }

                                ArrangeChip {
                                    visible: !chipCell.isTail
                                    icon: chipCell.page?.icon ?? "settings"
                                    label: chipCell.page?.name ?? "?"
                                    lifted: chipCell.chipLifted
                                    dimmed: root.liftActive && !chipCell.chipLifted
                                    onTapped: {
                                        root.lifted = chipCell.chipLifted ? null
                                            : ({ type: "page", ci: slotCol.index, pi: chipCell.index, pageIdx: chipCell.pageIdx })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Hidden zone: drop a page here and it leaves the sidebar entirely.
        // Search still finds hidden pages, and lifting a chip brings it back.
        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialSymbol {
                    text: "visibility_off"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: Translation.tr("Hidden pages")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("— out of the sidebar, still searchable")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                ArrangeDropSlot {
                    compact: true
                    active: root.liftIsPage && root.lifted.ci !== -1
                    onPlaced: root.hidePage()
                }

                Repeater {
                    model: SettingsPageRegistry.hiddenPages.length
                    delegate: ArrangeChip {
                        id: hiddenChip
                        required property int index
                        readonly property int pageIdx: SettingsPageRegistry.hiddenPages[hiddenChip.index] ?? -1
                        readonly property var page: SettingsPageRegistry.pages[hiddenChip.pageIdx] ?? null
                        readonly property bool chipLifted: root.liftIsPage
                            && root.lifted.ci === -1 && root.lifted.pi === hiddenChip.index
                        icon: hiddenChip.page?.icon ?? "settings"
                        label: hiddenChip.page?.name ?? "?"
                        lifted: chipLifted
                        dimmed: root.liftActive && !chipLifted
                        onTapped: {
                            root.lifted = hiddenChip.chipLifted ? null
                                : ({ type: "page", ci: -1, pi: hiddenChip.index, pageIdx: hiddenChip.pageIdx })
                        }
                    }
                }

                StyledText {
                    visible: SettingsPageRegistry.hiddenPages.length === 0 && !root.liftActive
                    text: Translation.tr("Nothing hidden")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
