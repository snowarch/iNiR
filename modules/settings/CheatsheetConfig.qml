import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 9
    settingsPageName: Translation.tr("Shortcuts")

    // ── Data sources ────────────────────────────────────────────────────────
    readonly property var keybinds: CompositorService.isNiri ? NiriKeybinds.keybinds : HyprlandKeybinds.keybinds
    readonly property var categories: keybinds?.children ?? []
    readonly property bool hasEnrichedData: CompositorService.isNiri && NiriKeybinds.enrichedCategories.length > 0
    readonly property bool canEdit: CompositorService.isNiri

    property var keySubstitutions: ({
        "Mod": "󰖳", "Super": "󰖳", "Slash": "/", "Return": "↵", "Escape": "Esc",
        "Comma": ",", "Period": ".", "BracketLeft": "[", "BracketRight": "]",
        "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
        "Page_Up": "PgUp", "Page_Down": "PgDn", "Home": "Home", "End": "End"
    })

    // ── Status feedback state ────────────────────────────────────────────────
    property string _statusMsg: ""
    property string _statusType: ""   // "saved" | "removed" | "error"
    property bool _statusVisible: false

    Connections {
        target: NiriKeybinds
        function onBindSaved(keyCombo) {
            root._statusMsg = Translation.tr("Saved: ") + keyCombo
            root._statusType = "saved"
            root._statusVisible = true
            statusHideTimer.restart()
        }
        function onBindRemoved(keyCombo) {
            root._statusMsg = Translation.tr("Removed: ") + keyCombo
            root._statusType = "removed"
            root._statusVisible = true
            statusHideTimer.restart()
        }
        function onBindError(message) {
            root._statusMsg = message
            root._statusType = "error"
            root._statusVisible = true
            statusHideTimer.stop()
        }
    }

    Timer {
        id: statusHideTimer
        interval: 3000
        repeat: false
        onTriggered: root._statusVisible = false
    }

    // ── Feedback bar ─────────────────────────────────────────────────────────
    Rectangle {
        visible: root._statusVisible
        Layout.fillWidth: true
        implicitHeight: statusBarRow.implicitHeight + 16
        radius: Appearance.rounding.small
        color: root._statusType === "error"
            ? ColorUtils.transparentize(Appearance.colors.colError, 0.82)
            : root._statusType === "removed"
            ? ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.7)
            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
        border.width: 1
        border.color: root._statusType === "error"
            ? ColorUtils.transparentize(Appearance.colors.colError, 0.45)
            : root._statusType === "removed"
            ? ColorUtils.transparentize(Appearance.colors.colSubtext, 0.55)
            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.45)

        RowLayout {
            id: statusBarRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 12
                rightMargin: 8
            }
            spacing: 8

            MaterialSymbol {
                text: root._statusType === "error" ? "error"
                    : root._statusType === "removed" ? "remove_circle"
                    : "check_circle"
                iconSize: Appearance.font.pixelSize.normal
                color: root._statusType === "error" ? Appearance.colors.colError
                    : root._statusType === "removed" ? Appearance.colors.colSubtext
                    : Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: root._statusMsg
                font.pixelSize: Appearance.font.pixelSize.small
                color: root._statusType === "error" ? Appearance.colors.colError
                    : root._statusType === "removed" ? Appearance.colors.colOnLayer1
                    : Appearance.colors.colPrimary
                wrapMode: Text.WordWrap
            }

            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                releaseAction: () => { root._statusVisible = false }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }

    // ── Load status section ──────────────────────────────────────────────────
    SettingsCardSection {
        expanded: true
        icon: NiriKeybinds.loaded ? "check_circle" : "info"
        title: NiriKeybinds.loaded
            ? Translation.tr("Keybinds loaded from config")
            : Translation.tr("Using default keybinds")
        visible: CompositorService.isNiri

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: NiriKeybinds.loaded
                    ? NiriKeybinds.configPath
                    : Translation.tr("Could not parse niri config, showing defaults")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Enriched categories (editor-capable) ────────────────────────────────
    ColumnLayout {
        visible: root.hasEnrichedData
        Layout.fillWidth: true
        spacing: 16

        Repeater {
            model: root.hasEnrichedData ? NiriKeybinds.enrichedCategories : []

            delegate: SettingsCardSection {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                expanded: false

                readonly property string catName: modelData?.name ?? ""
                readonly property var bindIndices: modelData?.binds ?? []

                icon: root.getCategoryIcon(catName)
                title: catName

                SettingsGroup {
                    Layout.fillWidth: true

                    Repeater {
                        id: enrichedBindRepeater
                        model: bindIndices

                        delegate: KeybindRow {
                            required property int modelData   // index into allBinds
                            required property int index
                            Layout.fillWidth: true

                            readonly property var bindData: NiriKeybinds.allBinds[modelData] ?? {}
                            readonly property var _parsed: root.parseComboParts(bindData.key_combo ?? "")

                            mods: _parsed.mods
                            keyName: _parsed.key
                            action: bindData.description ?? bindData.action ?? ""
                            showDivider: index < enrichedBindRepeater.count - 1
                            keyCombo: bindData.key_combo ?? ""
                            actionRaw: bindData.action ?? ""
                            optionsStr: bindData.options ?? ""
                            isCommented: bindData.commented ?? false
                            canEdit: root.canEdit
                            keySubstitutions: root.keySubstitutions
                        }
                    }
                }
            }
        }
    }

    // ── Legacy categories (read-only fallback) ───────────────────────────────
    ColumnLayout {
        visible: !root.hasEnrichedData
        Layout.fillWidth: true
        spacing: 16

        Repeater {
            model: root.categories

            delegate: SettingsCardSection {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                expanded: false

                readonly property var categoryKeybinds: modelData.children?.[0]?.keybinds ?? []

                icon: root.getCategoryIcon(modelData.name)
                title: modelData.name

                SettingsGroup {
                    Layout.fillWidth: true

                    Repeater {
                        id: legacyBindRepeater
                        model: categoryKeybinds

                        delegate: KeybindRow {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            mods: modelData.mods ?? []
                            keyName: modelData.key ?? ""
                            action: modelData.comment ?? ""
                            showDivider: index < legacyBindRepeater.count - 1
                            keyCombo: ""
                            actionRaw: ""
                            optionsStr: ""
                            isCommented: false
                            canEdit: false
                            keySubstitutions: root.keySubstitutions
                        }
                    }
                }
            }
        }
    }

    // ── Add keybind section ──────────────────────────────────────────────────
    SettingsCardSection {
        visible: root.canEdit
        Layout.fillWidth: true
        expanded: false
        icon: "add_circle"
        title: Translation.tr("Add keybind")

        SettingsGroup {
            Layout.fillWidth: true

            // Key combo
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Key combination")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                MaterialTextField {
                    id: addKeyComboField
                    Layout.fillWidth: true
                    placeholderText: "Mod+Tab"
                    enableSettingsSearch: false

                    readonly property string conflictDesc: {
                        const v = text.trim()
                        if (!v) return ""
                        const found = (NiriKeybinds.allBinds ?? []).find(b => b.key_combo === v && !b.commented)
                        return found ? (found.description ?? found.action ?? v) : ""
                    }
                }

                StyledText {
                    visible: addKeyComboField.conflictDesc !== ""
                    text: "⚠ " + Translation.tr("Already bound to: ") + "\"" + addKeyComboField.conflictDesc + "\""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colError
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // Action
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Action")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                MaterialTextField {
                    id: addActionField
                    Layout.fillWidth: true
                    placeholderText: "toggle-overview"
                    enableSettingsSearch: false
                }
            }

            // Options
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Options")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                MaterialTextField {
                    id: addOptionsField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("e.g. repeat=false")
                    enableSettingsSearch: false
                }
            }

            // Buttons
            RowLayout {
                spacing: 8

                DialogButton {
                    buttonText: Translation.tr("Add")
                    releaseAction: () => {
                        const combo = addKeyComboField.text.trim()
                        const action = addActionField.text.trim()
                        if (combo.length > 0 && action.length > 0) {
                            NiriKeybinds.setBind(combo, action, addOptionsField.text.trim())
                            addKeyComboField.text = ""
                            addActionField.text = ""
                            addOptionsField.text = ""
                        }
                    }
                }

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    releaseAction: () => {
                        addKeyComboField.text = ""
                        addActionField.text = ""
                        addOptionsField.text = ""
                    }
                }
            }
        }
    }

    Item { Layout.preferredHeight: 20 }

    // ── Functions ────────────────────────────────────────────────────────────

    function getCategoryIcon(name: string): string {
        const icons = {
            "System": "settings_power",
            "ii Shell": "auto_awesome",
            "iNiR Shell": "auto_awesome",
            "Window Switcher": "swap_horiz",
            "Screenshots": "screenshot_region",
            "Applications": "apps",
            "Window Management": "web_asset",
            "Focus": "center_focus_strong",
            "Move Windows": "open_with",
            "Workspaces": "grid_view",
            "Media": "volume_up",
            "Brightness": "light_mode",
            "Layout": "dashboard_customize",
            "Resize": "photo_size_select_large",
            "Monitors": "monitor",
            "Region Tools": "screenshot_region",
            "Other": "more_horiz"
        }
        return icons[name] ?? "keyboard"
    }

    function parseComboParts(combo: string): var {
        if (!combo || combo.length === 0)
            return { mods: [], key: "" }
        const parts = combo.split("+")
        if (parts.length === 1)
            return { mods: [], key: parts[0] }
        return {
            mods: parts.slice(0, parts.length - 1),
            key: parts[parts.length - 1]
        }
    }

    // ── KeyBadge component ───────────────────────────────────────────────────
    component KeyBadge: Rectangle {
        property string keyText: ""

        implicitWidth: Math.max(keyLabel.implicitWidth + 10, 26)
        implicitHeight: 22
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainerHigh ?? Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant ?? ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.85)

        StyledText {
            id: keyLabel
            anchors.centerIn: parent
            text: keyText
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.family: Appearance.font.family.monospace
            color: Appearance.colors.colOnLayer1
        }
    }

    // ── KeybindRow component ─────────────────────────────────────────────────
    component KeybindRow: Item {
        id: kbRow

        // Display properties
        property var mods: []
        property string keyName: ""
        property string action: ""
        property bool showDivider: true
        property bool isCommented: false

        // Edit properties (empty string = read-only / legacy mode)
        property string keyCombo: ""
        property string actionRaw: ""
        property string optionsStr: ""

        // Feature flags
        property bool canEdit: false
        property var keySubstitutions: ({})

        // State: "display" | "editing" | "confirmDelete"
        property string editState: "display"

        readonly property bool isExpanded: editState !== "display"

        // Drive outer height from inner column
        implicitHeight: kbMainColumn.implicitHeight

        clip: true

        // Hover background for display rows
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                bottomMargin: kbRow.showDivider ? 1 : 0
            }
            color: kbRowHover.containsMouse && kbRow.editState === "display"
                ? Appearance.colors.colLayer1Hover
                : "transparent"
            radius: Appearance.rounding.small

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                }
            }
        }

        MouseArea {
            id: kbRowHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            id: kbMainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            // ── Display row ──────────────────────────────────────────────────
            RowLayout {
                id: kbDisplayRow
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 12
                Layout.preferredHeight: 36

                // Key badges
                Row {
                    Layout.preferredWidth: 200
                    Layout.minimumWidth: 140
                    spacing: 4
                    opacity: kbRow.isCommented ? 0.4 : 1.0

                    Repeater {
                        model: kbRow.mods
                        delegate: KeyBadge {
                            required property var modelData
                            keyText: kbRow.keySubstitutions[modelData] ?? modelData
                        }
                    }

                    StyledText {
                        visible: kbRow.mods.length > 0 && kbRow.keyName.length > 0
                        text: "+"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    KeyBadge {
                        visible: kbRow.keyName.length > 0
                        keyText: kbRow.keySubstitutions[kbRow.keyName] ?? kbRow.keyName
                    }
                }

                // Action description
                StyledText {
                    Layout.fillWidth: true
                    text: kbRow.action + (kbRow.isCommented ? "  " + Translation.tr("(disabled)") : "")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: kbRow.isCommented
                        ? Appearance.colors.colSubtext
                        : Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }

                // Edit / delete icon buttons (enriched mode only, fade in on hover)
                Row {
                    visible: kbRow.canEdit && kbRow.editState === "display"
                    spacing: 2
                    opacity: kbRowHover.containsMouse ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                        }
                    }

                    RippleButton {
                        implicitWidth: 26
                        implicitHeight: 26
                        buttonRadius: Appearance.rounding.small
                        colBackground: "transparent"
                        releaseAction: () => { kbRow.editState = "editing" }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "edit"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }

                    RippleButton {
                        implicitWidth: 26
                        implicitHeight: 26
                        buttonRadius: Appearance.rounding.small
                        colBackground: "transparent"
                        releaseAction: () => { kbRow.editState = "confirmDelete" }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colError
                        }
                    }
                }
            }

            // ── Expand container (edit form + confirm delete) ────────────────
            Item {
                id: kbExpandContainer
                Layout.fillWidth: true
                implicitHeight: kbRow.isExpanded ? kbExpandInner.implicitHeight + 12 : 0
                clip: true

                Behavior on implicitHeight {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                ColumnLayout {
                    id: kbExpandInner
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 4
                        leftMargin: 8
                        rightMargin: 8
                    }
                    spacing: 0

                    // ── Edit form (Loader — instantiate only when active) ────
                    Loader {
                        id: editFormLoader
                        active: kbRow.editState === "editing"
                        visible: active
                        Layout.fillWidth: true

                        sourceComponent: Component {
                            ColumnLayout {
                                spacing: 8

                                // Key combo field
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    StyledText {
                                        text: Translation.tr("Key combination")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }

                                    MaterialTextField {
                                        id: editKeyField
                                        Layout.fillWidth: true
                                        text: kbRow.keyCombo
                                        placeholderText: "Mod+Tab"
                                        enableSettingsSearch: false

                                        readonly property string conflictDesc: {
                                            const v = text.trim()
                                            if (!v || v === kbRow.keyCombo) return ""
                                            const found = (NiriKeybinds.allBinds ?? []).find(
                                                b => b.key_combo === v && !b.commented
                                            )
                                            return found ? (found.description ?? found.action ?? v) : ""
                                        }
                                    }

                                    StyledText {
                                        visible: editKeyField.conflictDesc !== ""
                                        text: "⚠ " + Translation.tr("Already bound to: ") + "\"" + editKeyField.conflictDesc + "\""
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colError
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }

                                // Action field
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    StyledText {
                                        text: Translation.tr("Action")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }

                                    MaterialTextField {
                                        id: editActionField
                                        Layout.fillWidth: true
                                        text: kbRow.actionRaw
                                        placeholderText: "toggle-overview"
                                        enableSettingsSearch: false
                                    }
                                }

                                // Options field
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    StyledText {
                                        text: Translation.tr("Options")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }

                                    MaterialTextField {
                                        id: editOptionsField
                                        Layout.fillWidth: true
                                        text: kbRow.optionsStr
                                        placeholderText: Translation.tr("e.g. repeat=false")
                                        enableSettingsSearch: false
                                    }
                                }

                                // Save / Cancel
                                RowLayout {
                                    spacing: 8

                                    DialogButton {
                                        buttonText: Translation.tr("Save")
                                        releaseAction: () => {
                                            const combo = editKeyField.text.trim()
                                            const act = editActionField.text.trim()
                                            if (combo.length > 0 && act.length > 0) {
                                                NiriKeybinds.setBind(combo, act, editOptionsField.text.trim())
                                                kbRow.editState = "display"
                                            }
                                        }
                                    }

                                    DialogButton {
                                        buttonText: Translation.tr("Cancel")
                                        releaseAction: () => { kbRow.editState = "display" }
                                    }
                                }
                            }
                        }
                    }

                    // ── Confirm delete ───────────────────────────────────────
                    Loader {
                        id: confirmDeleteLoader
                        active: kbRow.editState === "confirmDelete"
                        visible: active
                        Layout.fillWidth: true

                        sourceComponent: Component {
                            RowLayout {
                                spacing: 8
                                Layout.bottomMargin: 4

                                MaterialSymbol {
                                    text: "warning"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colError
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Remove keybind ") + kbRow.keyCombo + "?"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                    wrapMode: Text.WordWrap
                                }

                                DialogButton {
                                    buttonText: Translation.tr("Remove")
                                    colText: Appearance.colors.colError
                                    releaseAction: () => {
                                        NiriKeybinds.removeBind(kbRow.keyCombo)
                                        kbRow.editState = "display"
                                    }
                                }

                                DialogButton {
                                    buttonText: Translation.tr("Cancel")
                                    releaseAction: () => { kbRow.editState = "display" }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom divider
        Rectangle {
            visible: kbRow.showDivider
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            height: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.3
        }
    }
}
