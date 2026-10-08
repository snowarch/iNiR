pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.background.widgets
import "../background/widgets/OrganicEdgeConfig.js" as EdgeConfig

ColumnLayout {
    id: root
    spacing: 12
    function value(key: string): var {
        return Config.getNestedValue(EdgeConfig.path + "." + key, EdgeConfig.defaults[key])
    }
    function setValue(key: string, value): void {
        Config.setNestedValue(EdgeConfig.path + "." + key, value)
    }
    function applyValues(values): void {
        const updates = {}
        for (const key of Object.keys(values)) updates[EdgeConfig.path + "." + key] = values[key]
        Config.setNestedValues(updates)
    }
    function valuesEqual(first, second): bool {
        if (Array.isArray(first) || Array.isArray(second)) {
            const a = Array.isArray(first) ? first.map(v => String(v)).sort() : []
            const b = Array.isArray(second) ? second.map(v => String(v)).sort() : []
            return JSON.stringify(a) === JSON.stringify(b)
        }
        return first === second
    }
    function isDefault(key: string): bool {
        return root.valuesEqual(root.value(key), EdgeConfig.defaults[key])
    }
    function resetValue(key: string): void {
        root.setValue(key, EdgeConfig.defaults[key])
    }
    function resetKeys(keys): void {
        root.applyValues(EdgeConfig.defaultValues(keys))
    }
    function groupModified(keys): bool {
        for (let i = 0; i < keys.length; ++i)
            if (!root.isDefault(keys[i])) return true
        return false
    }
    readonly property var selectedEdges: EdgeConfig.selectedEdges(root.value("edges"), root.value("edge"))
    function presetMatches(preset): bool {
        for (const key of Object.keys(preset.values)) {
            const current = root.value(key)
            const expected = preset.values[key]
            if (Array.isArray(expected)) {
                const actualList = []
                if (current && typeof current.length === "number") {
                    for (let i = 0; i < current.length; ++i)
                        actualList.push(String(current[i]))
                    actualList.sort()
                }
                const expectedList = expected.slice().sort()
                if (JSON.stringify(actualList) !== JSON.stringify(expectedList)) return false
            } else if (current !== expected) return false
        }
        return true
    }
    function metricVisible(key: string): bool {
        if (key === "topScale") return root.selectedEdges.includes("top")
        if (key === "rightScale") return root.selectedEdges.includes("right")
        if (key === "bottomScale") return root.selectedEdges.includes("bottom")
        if (key === "leftScale") return root.selectedEdges.includes("left")
        return true
    }
    function metricEnabled(key: string): bool {
        if (["sensitivity", "audioRange", "pulse", "beatGlow", "transientStrength", "bassDrive",
                "trebleDrive", "attack", "release", "compression", "smoothing",
                "accentStrength"].includes(key)
                && !root.value("audioReactive")) return false
        if (key === "accentStrength" && root.value("frequencyProfile") === "flat") return false
        if (key === "position" && Number(root.value("span")) >= 100) return false
        if (key === "taper" && Number(root.value("span")) >= 100
                && root.selectedEdges.length === 4) return false
        if (key === "cornerBlend" && root.value("joinMode") === "separate") return false
        if (key === "colorSpeed" && (root.value("palette") === "mono"
                || root.value("colorMode") === "static")) return false
        if (key === "effectStrength" && root.value("effectMode") === "clean") return false
        if (key === "restPresence" && root.value("idleMode") === "hidden") return false
        return true
    }
    function hasJoinedCorner(edges, joinMode): bool {
        if (String(joinMode) === "separate") return false
        const list = Array.isArray(edges) ? edges : []
        return (list.includes("top") && list.includes("right"))
            || (list.includes("right") && list.includes("bottom"))
            || (list.includes("bottom") && list.includes("left"))
            || (list.includes("left") && list.includes("top"))
    }
    function topologySummary(): string {
        const joinMode = root.value("joinMode")
        if (String(joinMode) === "separate")
            return Translation.tr("Independent rails")
        if (root.hasJoinedCorner(root.selectedEdges, joinMode))
            return Translation.tr("Continuous corner handoff")
        return root.selectedEdges.length === 1
            ? Translation.tr("Single edge") : Translation.tr("Independent sides")
    }

    component ResetButton: RippleButton {
        id: resetButton
        property string tooltipText: Translation.tr("Reset to default")
        signal resetRequested()
        implicitWidth: 26
        implicitHeight: 26
        buttonRadius: 13
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        onClicked: resetRequested()
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: "restart_alt"
            iconSize: 15
            color: Appearance.colors.colOnLayer2
        }
        StyledToolTip { text: resetButton.tooltipText; visible: resetButton.buttonHovered }
    }

    component GroupHeader: RowLayout {
        id: groupHeader
        required property string label
        property string description: ""
        property var resetKeys: []
        Layout.fillWidth: true
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                Layout.fillWidth: true
                text: groupHeader.label
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.fillWidth: true
                visible: groupHeader.description.length > 0
                text: groupHeader.description
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.Wrap
            }
        }
        ResetButton {
            visible: groupHeader.resetKeys.length > 0 && root.groupModified(groupHeader.resetKeys)
            tooltipText: Translation.tr("Reset this section")
            onResetRequested: root.resetKeys(groupHeader.resetKeys)
        }
    }

    component SelectionBlock: ColumnLayout {
        id: selectionBlock
        required property string label
        required property string settingKey
        required property var options
        property bool controlEnabled: true
        property var displayValue: root.value(settingKey)
        Layout.fillWidth: true
        spacing: 5
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: selectionBlock.label
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }
            ResetButton {
                visible: !root.isDefault(selectionBlock.settingKey)
                tooltipText: Translation.tr("Reset") + " " + selectionBlock.label
                onResetRequested: root.resetValue(selectionBlock.settingKey)
            }
        }
        ConfigSelectionArray {
            Layout.fillWidth: true
            enabled: selectionBlock.controlEnabled
            opacity: enabled ? 1 : 0.45
            currentValue: selectionBlock.displayValue
            onSelected: newValue => root.setValue(selectionBlock.settingKey, newValue)
            options: selectionBlock.options
        }
    }

    component Metrics: GridLayout {
        id: metrics
        required property var entries
        Layout.fillWidth: true
        columns: width >= 660 ? 2 : 1
        columnSpacing: 24
        rowSpacing: 8
        Repeater {
            model: metrics.entries
            ColumnLayout {
                id: metric
                required property var modelData
                Layout.fillWidth: true
                visible: root.metricVisible(modelData.key)
                spacing: 3
                enabled: root.metricEnabled(modelData.key)
                opacity: enabled ? 1 : 0.45
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr(metric.modelData.label)
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: Math.round(Number(root.value(metric.modelData.key))) + metric.modelData.unit
                        color: Appearance.colors.colPrimary
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.numbers
                        font.weight: Font.DemiBold
                    }
                    ResetButton {
                        visible: !root.isDefault(metric.modelData.key)
                        tooltipText: Translation.tr("Reset") + " " + Translation.tr(metric.modelData.label)
                        onResetRequested: root.resetValue(metric.modelData.key)
                    }
                }
                StyledSlider {
                    Layout.fillWidth: true
                    from: metric.modelData.min
                    to: metric.modelData.max
                    stepSize: metric.modelData.step
                    value: Number(root.value(metric.modelData.key))
                    configuration: StyledSlider.Configuration.XS
                    stopIndicatorValues: []
                    tooltipContent: Math.round(value) + metric.modelData.unit
                    onMoved: root.setValue(metric.modelData.key, Math.round(value))
                }
            }
        }
    }

    component SectionLabel: StyledText {
        Layout.fillWidth: true
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
    }

    component PresetTile: Rectangle {
        id: presetTile
        required property var preset
        readonly property bool selected: root.presetMatches(preset)
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitHeight: 82
        radius: Appearance.rounding.small
        color: selected
            ? Appearance.colors.colPrimaryContainer
            : presetHover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        border.width: selected ? 2 : 1
        border.color: selected ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: presetTile.selected
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colLayer3

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: presetTile.preset.icon
                    iconSize: 20
                    fill: 1
                    color: presetTile.selected
                        ? Appearance.colors.colOnPrimary
                        : Appearance.colors.colOnLayer2
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr(presetTile.preset.name)
                    color: presetTile.selected
                        ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr(presetTile.preset.description)
                    color: presetTile.selected
                        ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colSubtext
                    opacity: 0.78
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                visible: presetTile.selected
                text: "check_circle"
                iconSize: 18
                fill: 1
                color: Appearance.colors.colPrimary
            }
        }

        HoverHandler { id: presetHover }
        TapHandler { onTapped: root.applyValues(presetTile.preset.values) }
    }

    component EdgeDiagram: Item {
        id: diagram
        property var edges: []
        property bool joined: true
        implicitWidth: 48
        implicitHeight: 34

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: "transparent"
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
            opacity: 0.9
        }
        Rectangle {
            visible: diagram.edges.includes("top")
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            radius: 2
            color: Appearance.colors.colPrimary
        }
        Rectangle {
            visible: diagram.edges.includes("right")
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 3
            radius: 2
            color: Appearance.colors.colPrimary
        }
        Rectangle {
            visible: diagram.edges.includes("bottom")
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 3
            radius: 2
            color: Appearance.colors.colPrimary
        }
        Rectangle {
            visible: diagram.edges.includes("left")
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 3
            radius: 2
            color: Appearance.colors.colPrimary
        }
        MaterialSymbol {
            visible: diagram.joined && diagram.edges.length > 1
            anchors.centerIn: parent
            text: "join_inner"
            iconSize: 13
            color: Appearance.colors.colSubtext
        }
    }

    component CompositionTile: Rectangle {
        id: compositionTile
        required property var preset
        readonly property bool selected: root.presetMatches(preset)
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitHeight: 70
        radius: Appearance.rounding.small
        color: selected ? Appearance.colors.colPrimaryContainer
            : compositionHover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        border.width: selected ? 2 : 1
        border.color: selected ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            EdgeDiagram {
                edges: compositionTile.preset.values.edges ?? []
                joined: root.hasJoinedCorner(edges, compositionTile.preset.values.joinMode ?? "auto")
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr(compositionTile.preset.name)
                    color: compositionTile.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr(compositionTile.preset.description)
                    color: compositionTile.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    opacity: 0.8
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
            }
        }
        HoverHandler { id: compositionHover }
        TapHandler { onTapped: root.applyValues(compositionTile.preset.values) }
    }

    SettingsCardSection {
        Layout.fillWidth: true
        settingsTaskSection: "edges"
        title: Translation.tr("Organic edge")
        icon: "border_outer"
        expanded: true
        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: true
                    text: Translation.tr("Enable Organic edge")
                    buttonIcon: "border_outer"
                    checked: root.value("enable")
                    autoToggle: false
                    onToggledByUser: checked => root.setValue("enable", checked)
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 66
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 12
                    EdgeDiagram {
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 40
                        edges: root.selectedEdges
                        joined: root.hasJoinedCorner(root.selectedEdges, root.value("joinMode"))
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        StyledText {
                            Layout.fillWidth: true
                            text: root.selectedEdges.length === 4
                                ? Translation.tr("Full perimeter")
                                : Translation.tr("%1 active sides").arg(root.selectedEdges.length)
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.topologySummary()
                                + " · " + (root.value("audioReactive")
                                    ? Translation.tr("music reactive") : Translation.tr("ambient only"))
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            GroupHeader {
                label: Translation.tr("Scenes")
                description: Translation.tr("Curated combinations with a specific visual and musical intent. Use the sections below when you want to change one dimension without disturbing the others.")
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width >= 620 ? 2 : 1
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: EdgeConfig.scenePresets
                    PresetTile {
                        required property var modelData
                        preset: modelData
                    }
                }
            }
            WidgetChoiceButton {
                Layout.fillWidth: true
                buttonIcon: "restart_alt"
                buttonText: Translation.tr("Reset Organic edge")
                onClicked: {
                    const values = Object.assign({}, EdgeConfig.defaults)
                    delete values.enable
                    delete values.screenList
                    root.applyValues(values)
                }
            }
        }
    }

    SettingsCardSection {
        Layout.fillWidth: true
        settingsTaskSection: "edges"
        title: Translation.tr("Screen composition")
        icon: "select_all"
        expanded: false
        SettingsGroup {
            GroupHeader {
                label: Translation.tr("Compositions")
                description: Translation.tr("These presets change only placement and topology. Your material, palette and music response stay intact.")
                resetKeys: EdgeConfig.compositionKeys
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width >= 620 ? 2 : 1
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: EdgeConfig.compositionPresets
                    CompositionTile {
                        required property var modelData
                        preset: modelData
                    }
                }
            }
            GroupHeader {
                label: Translation.tr("Active sides")
                resetKeys: ["edges"]
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width >= 480 ? 4 : 2
                columnSpacing: 6
                rowSpacing: 6
                Repeater {
                    model: [{key: "top", label: "Top", icon: "border_top"},
                        {key: "right", label: "Right", icon: "border_right"},
                        {key: "bottom", label: "Bottom", icon: "border_bottom"},
                        {key: "left", label: "Left", icon: "border_left"}]
                    WidgetChoiceButton {
                        required property var modelData
                        Layout.fillWidth: true
                        buttonText: Translation.tr(modelData.label)
                        buttonIcon: modelData.icon
                        toggled: root.selectedEdges.includes(modelData.key)
                        onClicked: {
                            const edges = root.selectedEdges.slice()
                            const index = edges.indexOf(modelData.key)
                            if (index < 0) edges.push(modelData.key)
                            else if (edges.length > 1) edges.splice(index, 1)
                            root.setValue("edges", edges)
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: true
                    text: Translation.tr("Respect bars and dock")
                    buttonIcon: "space_dashboard"
                    checked: root.value("respectPanels")
                    autoToggle: false
                    onToggledByUser: checked => root.setValue("respectPanels", checked)
                }
                ResetButton {
                    visible: !root.isDefault("respectPanels")
                    tooltipText: Translation.tr("Reset panel avoidance")
                    onResetRequested: root.resetValue("respectPanels")
                }
            }
            SelectionBlock {
                label: Translation.tr("Corner relationship")
                settingKey: "joinMode"
                options: [
                    {displayName: Translation.tr("Join connected edges"), value: "auto"},
                    {displayName: Translation.tr("Keep edges separate"), value: "separate"}
                ]
            }
            GroupHeader {
                label: Translation.tr("Geometry")
                description: Translation.tr("Corner radius follows the physical display mask; Corner handoff controls how strongly adjacent full-length edges merge into one field.")
                resetKeys: ["span", "position", "depth", "inset", "topScale", "rightScale",
                    "bottomScale", "leftScale", "cornerRadius", "cornerBlend", "taper"]
            }
            Metrics { entries: EdgeConfig.geometry }
        }
    }

    SettingsCardSection {
        Layout.fillWidth: true
        settingsTaskSection: "edges"
        title: Translation.tr("Material and palette")
        icon: "palette"
        expanded: false
        SettingsGroup {
            GroupHeader {
                label: Translation.tr("Material presets")
                description: Translation.tr("Material presets alter body, contour and light only. They do not change your edge layout, palette or music tuning.")
                resetKeys: EdgeConfig.materialKeys
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width >= 620 ? 2 : 1
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: EdgeConfig.materialPresets
                    PresetTile {
                        required property var modelData
                        preset: modelData
                    }
                }
            }
            SelectionBlock {
                label: Translation.tr("Material")
                settingKey: "style"
                options: [{displayName: Translation.tr("Silk"), value: "silk"},
                    {displayName: Translation.tr("Aurora"), value: "aurora"},
                    {displayName: Translation.tr("Contour"), value: "contour"},
                    {displayName: Translation.tr("Liquid"), value: "liquid"}]
            }
            SelectionBlock {
                label: Translation.tr("Contour language")
                settingKey: "shape"
                options: EdgeConfig.shapes.map(p => ({displayName: Translation.tr(p.name), value: p.value}))
            }
            GroupHeader {
                label: Translation.tr("Color")
                description: Translation.tr("Choose where color comes from and how it travels. The visual effect changes light behavior, not the underlying palette.")
                resetKeys: EdgeConfig.colorKeys
            }
            SelectionBlock {
                label: Translation.tr("Palette source")
                settingKey: "palette"
                displayValue: EdgeConfig.paletteValue(root.value("palette"))
                options: EdgeConfig.palettes.map(p => ({displayName: Translation.tr(p.name), value: p.value}))
            }
            SelectionBlock {
                label: Translation.tr("Color movement")
                settingKey: "colorMode"
                options: EdgeConfig.colorModes.map(p => ({displayName: Translation.tr(p.name), value: p.value}))
            }
            SelectionBlock {
                label: Translation.tr("Light behavior")
                settingKey: "effectMode"
                options: EdgeConfig.effects.map(p => ({displayName: Translation.tr(p.name), value: p.value}))
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.value("palette") === "custom"
                Repeater {
                    model: [{label: "Primary", key: "primaryColor"},
                        {label: "Secondary", key: "secondaryColor"},
                        {label: "Tertiary", key: "tertiaryColor"}]
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        ColorPickerRow {
                            Layout.fillWidth: true
                            label: Translation.tr(modelData.label)
                            colorKey: modelData.key
                            configPath: EdgeConfig.path + "." + colorKey
                        }
                        ResetButton {
                            visible: !root.isDefault(modelData.key)
                            tooltipText: Translation.tr("Reset") + " " + Translation.tr(modelData.label)
                            onResetRequested: root.resetValue(modelData.key)
                        }
                    }
                }
            }
            GroupHeader {
                label: Translation.tr("Body")
                resetKeys: EdgeConfig.materialBody.map(item => item.key)
            }
            Metrics { entries: EdgeConfig.materialBody }
            GroupHeader {
                label: Translation.tr("Light")
                resetKeys: EdgeConfig.materialLight.map(item => item.key)
            }
            Metrics { entries: EdgeConfig.materialLight }
            GroupHeader {
                label: Translation.tr("Color tuning")
                resetKeys: EdgeConfig.colorTuning.map(item => item.key)
            }
            Metrics { entries: EdgeConfig.colorTuning }
        }
    }

    SettingsCardSection {
        Layout.fillWidth: true
        settingsTaskSection: "edges"
        title: Translation.tr("Motion and sound")
        icon: "graphic_eq"
        expanded: false
        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: true
                    text: Translation.tr("React to audio")
                    buttonIcon: "equalizer"
                    checked: root.value("audioReactive")
                    autoToggle: false
                    onToggledByUser: checked => root.setValue("audioReactive", checked)
                }
                ResetButton {
                    visible: !root.isDefault("audioReactive")
                    tooltipText: Translation.tr("Reset audio reaction")
                    onResetRequested: root.resetValue("audioReactive")
                }
            }
            GroupHeader {
                label: Translation.tr("Rest state")
                description: Translation.tr("Silence is a designed state: keep a low ambient current, settle into a still frame, or fade the field out after its remaining energy decays.")
                resetKeys: EdgeConfig.idleKeys
            }
            SelectionBlock {
                label: Translation.tr("When silent")
                settingKey: "idleMode"
                options: [{displayName: Translation.tr("Ambient"), value: "ambient"},
                    {displayName: Translation.tr("Still when silent"), value: "still"},
                    {displayName: Translation.tr("Hide when silent"), value: "hidden"}]
            }
            Metrics { entries: EdgeConfig.idle }
            GroupHeader {
                label: Translation.tr("Response presets")
                description: Translation.tr("These tune envelope and frequency response only; they never change the visual composition.")
                resetKeys: EdgeConfig.responseKeys
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width >= 600 ? 5 : width >= 420 ? 3 : 2
                columnSpacing: 6
                rowSpacing: 6
                Repeater {
                    model: EdgeConfig.responsePresets
                    WidgetChoiceButton {
                        required property var modelData
                        Layout.fillWidth: true
                        buttonText: Translation.tr(modelData.name)
                        buttonIcon: modelData.icon
                        toggled: root.presetMatches(modelData)
                        enabled: root.value("audioReactive")
                        onClicked: root.applyValues(modelData.values)
                    }
                }
            }
            SelectionBlock {
                label: Translation.tr("Frequency focus")
                settingKey: "frequencyProfile"
                controlEnabled: root.value("audioReactive")
                options: [{displayName: Translation.tr("Balanced"), value: "flat"},
                    {displayName: Translation.tr("Bass"), value: "bass"},
                    {displayName: Translation.tr("Warm"), value: "warm"},
                    {displayName: Translation.tr("Vocals"), value: "vocal"},
                    {displayName: Translation.tr("Treble"), value: "treble"},
                    {displayName: Translation.tr("Bass + treble"), value: "smile"}]
            }
            GroupHeader {
                label: Translation.tr("Movement")
                resetKeys: EdgeConfig.motionKeys
            }
            SelectionBlock {
                label: Translation.tr("Travel direction")
                settingKey: "flowDirection"
                options: [{displayName: Translation.tr("Clockwise"), value: "clockwise"},
                    {displayName: Translation.tr("Counter-clockwise"), value: "counterclockwise"}]
            }
            Metrics { entries: EdgeConfig.motion }
            GroupHeader {
                label: Translation.tr("Music dynamics")
                resetKeys: EdgeConfig.audioDynamics.map(item => item.key)
            }
            Metrics { entries: EdgeConfig.audioDynamics }
            GroupHeader {
                label: Translation.tr("Frequency character")
                resetKeys: EdgeConfig.audioTone.map(item => item.key)
            }
            Metrics { entries: EdgeConfig.audioTone }
            SettingsNote { text: Translation.tr("Bass moves the body, mids shape local groove, treble concentrates in the crest and light, and transients create short-lived motion. Attack catches the hit; Release controls how naturally the field returns to rest.") }
        }
    }

    SettingsCardSection {
        Layout.fillWidth: true
        settingsTaskSection: "edges"
        title: Translation.tr("Displays")
        icon: "monitor"
        expanded: false
        SettingsGroup {
            GroupHeader {
                label: Translation.tr("Display scope")
                description: Translation.tr("Choose where this field is allowed to render. Reset returns Organic edge to all displays without changing its scene.")
                resetKeys: ["screenList"]
            }
            SettingsSwitch {
                visible: Quickshell.screens.length > 1
                text: Translation.tr("All displays")
                buttonIcon: "desktop_windows"
                checked: (root.value("screenList") ?? []).length === 0
                autoToggle: false
                onToggledByUser: checked => root.setValue("screenList", checked ? []
                    : (Quickshell.screens.length > 0 ? [Quickshell.screens[0].name] : []))
            }
            Repeater {
                model: Quickshell.screens
                SettingsSwitch {
                    required property var modelData
                    text: modelData.name
                    buttonIcon: "monitor"
                    readonly property var configured: root.value("screenList") ?? []
                    checked: configured.length === 0 || configured.includes(modelData.name)
                    autoToggle: false
                    enabled: !checked || (configured.length || Quickshell.screens.length) > 1
                    onToggledByUser: checked => {
                        const screens = configured.length ? configured.slice() : Quickshell.screens.map(s => s.name)
                        const index = screens.indexOf(modelData.name)
                        if (checked && index < 0) screens.push(modelData.name)
                        if (!checked && index >= 0) screens.splice(index, 1)
                        if (screens.length === 0) root.setValue("enable", false)
                        else if (screens.length === Quickshell.screens.length) root.setValue("screenList", [])
                        else root.setValue("screenList", screens)
                    }
                }
            }
        }
    }
}
