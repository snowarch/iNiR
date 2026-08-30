import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 27
    settingsPageName: Translation.tr("Orbit")
    property string activeSection: "activation"

    readonly property var orbitOptions: Config.options?.orbit ?? {}
    readonly property var shelfOptions: orbitOptions.shelf ?? {}
    readonly property var shelfModules: Array.isArray(shelfOptions.modules)
        ? shelfOptions.modules : ["locator", "trail", "niri", "actions", "stash"]
    readonly property var actionOptions: {
        const result = [{ value: "", displayName: Translation.tr("None") }]
        for (const action of GlobalActions.allActions ?? []) {
            result.push({
                value: action.id,
                displayName: `${action.name} · ${action.category}`
            })
        }
        return result
    }

    function pinnedAction(slot: int): string {
        const defaults = ["open-clipboard", "toggle-tiling", "toggle-dashboard"]
        const actions = Array.isArray(root.shelfOptions.pinnedActions)
            ? root.shelfOptions.pinnedActions : defaults
        return actions[slot] ?? ""
    }

    function actionChoiceIndex(value: string): int {
        const index = root.actionOptions.findIndex(option => option.value === value)
        return index >= 0 ? index : 0
    }

    function setPinnedAction(slot: int, actionId: string): void {
        const defaults = ["open-clipboard", "toggle-tiling", "toggle-dashboard"]
        const actions = Array.isArray(root.shelfOptions.pinnedActions)
            ? [...root.shelfOptions.pinnedActions] : defaults
        while (actions.length < 3) actions.push("")
        actions[slot] = actionId
        Config.setNestedValue("orbit.shelf.pinnedActions", actions)
    }

    SettingsTaskNavigator {
        icon: "hub"
        title: Translation.tr("Orbit")
        description: Translation.tr("Shape the Niri workspace navigator around how you move through windows every day.")
        summary: Translation.tr("Activation · layout · navigation · shelf · motion")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        options: [
            { displayName: Translation.tr("Activation"), icon: "ads_click", value: "activation" },
            { displayName: Translation.tr("Layout"), icon: "view_carousel", value: "layout" },
            { displayName: Translation.tr("Navigation"), icon: "route", value: "navigation" },
            { displayName: Translation.tr("Shelf"), icon: "shelf_auto_hide", value: "shelf" },
            { displayName: Translation.tr("Motion"), icon: "animation", value: "motion" }
        ]
    }

    SettingsCardSection {
        settingsTaskSection: "activation"
        visible: root.activeSection === "activation"
        expanded: true
        icon: "ads_click"
        title: Translation.tr("Activation")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: CompositorService.isNiri
                    ? Translation.tr("Orbit is a Material workspace navigator built for Niri. The taskview IPC remains as a compatibility alias.")
                    : Translation.tr("Orbit is currently available on Niri.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            ConfigSwitch {
                text: Translation.tr("Enable Orbit")
                description: Translation.tr("Allow Orbit to open from its hot corner and IPC entry point")
                checked: root.orbitOptions.enable ?? true
                onCheckedChanged: Config.setNestedValue("orbit.enable", checked)
            }

            ConfigSwitch {
                enabled: root.orbitOptions.enable ?? true
                text: Translation.tr("Hot corner")
                description: Translation.tr("Open Orbit by pushing the pointer into the selected screen corner")
                checked: root.orbitOptions.hotCornerEnable ?? true
                onCheckedChanged: Config.setNestedValue("orbit.hotCornerEnable", checked)
            }

            ContentSubsection {
                title: Translation.tr("Corner")
                enabled: (root.orbitOptions.enable ?? true) && (root.orbitOptions.hotCornerEnable ?? true)

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.hotCorner ?? "topRight"
                    onSelected: value => Config.setNestedValue("orbit.hotCorner", value)
                    options: [
                        { displayName: Translation.tr("Top left"), icon: "north_west", value: "topLeft" },
                        { displayName: Translation.tr("Top right"), icon: "north_east", value: "topRight" },
                        { displayName: Translation.tr("Bottom left"), icon: "south_west", value: "bottomLeft" },
                        { displayName: Translation.tr("Bottom right"), icon: "south_east", value: "bottomRight" }
                    ]
                }
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: (root.orbitOptions.enable ?? true) && (root.orbitOptions.hotCornerEnable ?? true)
                icon: "crop_free"
                text: Translation.tr("Corner target size")
                description: Translation.tr("Invisible square used to catch the corner gesture")
                value: root.orbitOptions.hotCornerSize ?? 12
                from: 4
                to: 40
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.hotCornerSize", value)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: (root.orbitOptions.enable ?? true) && (root.orbitOptions.hotCornerEnable ?? true)
                icon: "timer"
                text: Translation.tr("Corner dwell")
                description: Translation.tr("Milliseconds to hold the pointer in the exact corner; 0 opens immediately")
                value: root.orbitOptions.hotCornerDwellMs ?? 0
                from: 0
                to: 500
                stepSize: 25
                onValueChanged: Config.setNestedValue("orbit.hotCornerDwellMs", value)
            }

            RippleButtonWithIcon {
                enabled: CompositorService.isNiri && (root.orbitOptions.enable ?? true)
                materialIcon: "open_in_full"
                mainText: Translation.tr("Open Orbit")
                onClicked: GlobalStates.openOrbit("")
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "layout"
        visible: root.activeSection === "layout"
        expanded: true
        icon: "view_carousel"
        title: Translation.tr("Workspace layout")

        SettingsGroup {
            ConfigSpinBox {
                Layout.fillWidth: true
                icon: "view_week"
                text: Translation.tr("Visible workspaces")
                value: root.orbitOptions.workspaceCount ?? 3
                from: 1
                to: 5
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.workspaceCount", value)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                icon: "zoom_out_map"
                text: Translation.tr("Workspace scale")
                description: Translation.tr("Percentage of the monitor size used by each workspace preview")
                value: root.orbitOptions.workspaceScalePercent ?? 27
                from: 16
                to: 42
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.workspaceScalePercent", value)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                icon: "width"
                text: Translation.tr("Maximum panel width")
                value: root.orbitOptions.maxPanelWidthPercent ?? 92
                from: 60
                to: 100
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.maxPanelWidthPercent", value)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                icon: "space_bar"
                text: Translation.tr("Workspace spacing")
                value: root.orbitOptions.workspaceSpacing ?? 18
                from: 0
                to: 40
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.workspaceSpacing", value)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                icon: "grid_view"
                text: Translation.tr("Window gap")
                value: root.orbitOptions.windowGap ?? 4
                from: 0
                to: 16
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.windowGap", value)
            }

            ConfigSwitch {
                text: Translation.tr("Balanced window grid")
                description: Translation.tr("Prefer readable 2D cards instead of reproducing Niri's scrolling columns literally")
                checked: root.orbitOptions.balancedGrid ?? true
                onCheckedChanged: Config.setNestedValue("orbit.balancedGrid", checked)
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "navigation"
        visible: root.activeSection === "navigation"
        expanded: true
        icon: "route"
        title: Translation.tr("Navigation")

        SettingsGroup {
            ConfigSwitch {
                text: Translation.tr("Close after selecting a window")
                checked: root.orbitOptions.closeOnSelect ?? true
                onCheckedChanged: Config.setNestedValue("orbit.closeOnSelect", checked)
            }

            ConfigSwitch {
                text: Translation.tr("Scroll between workspaces")
                checked: root.orbitOptions.scrollNavigation ?? true
                onCheckedChanged: Config.setNestedValue("orbit.scrollNavigation", checked)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: root.orbitOptions.scrollNavigation ?? true
                icon: "speed"
                text: Translation.tr("Scroll steps")
                value: root.orbitOptions.scrollSteps ?? 1
                from: 1
                to: 4
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.scrollSteps", value)
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "shelf"
        visible: root.activeSection === "shelf"
        expanded: true
        icon: "shelf_auto_hide"
        title: Translation.tr("Orbit Shelf")

        SettingsGroup {
            ConfigSwitch {
                text: Translation.tr("Show Shelf")
                description: Translation.tr("Keep fast window history, Niri controls and shell actions below the workspace band")
                checked: root.shelfOptions.enable ?? true
                onCheckedChanged: Config.setNestedValue("orbit.shelf.enable", checked)
            }

            ConfigSwitch {
                enabled: root.shelfOptions.enable ?? true
                text: Translation.tr("Recent window Trail")
                description: Translation.tr("Allow the Trail module to surface recently focused windows")
                checked: root.orbitOptions.showTrail ?? true
                onCheckedChanged: Config.setNestedValue("orbit.showTrail", checked)
            }

            ConfigSwitch {
                enabled: root.shelfOptions.enable ?? true
                text: Translation.tr("Enable Stash")
                description: Translation.tr("Reveal the Stash drop target while dragging; its Shelf module can be hidden independently")
                checked: root.orbitOptions.showStash ?? true
                onCheckedChanged: Config.setNestedValue("orbit.showStash", checked)
            }

            OrbitShelfEditor {
                enabled: root.shelfOptions.enable ?? true
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: (root.shelfOptions.enable ?? true)
                    && root.shelfModules.includes("trail")
                    && (root.orbitOptions.showTrail ?? true)
                icon: "history"
                text: Translation.tr("Trail windows")
                description: Translation.tr("Maximum recent windows shown before the Shelf switches to icon-only layout")
                value: root.orbitOptions.trailItems ?? 5
                from: 2
                to: 8
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.trailItems", value)
            }

            ContentSubsection {
                title: Translation.tr("Restore stashed windows")
                enabled: (root.shelfOptions.enable ?? true)
                    && root.shelfModules.includes("stash")
                    && (root.orbitOptions.showStash ?? true)

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.stashRestoreMode ?? "original"
                    onSelected: value => Config.setNestedValue("orbit.stashRestoreMode", value)
                    options: [
                        { displayName: Translation.tr("Original workspace"), icon: "undo", value: "original" },
                        { displayName: Translation.tr("Current workspace"), icon: "my_location", value: "current" }
                    ]
                }
            }

            ConfigSwitch {
                enabled: (root.shelfOptions.enable ?? true)
                    && root.shelfModules.includes("actions")
                text: Translation.tr("Close Orbit after an action")
                description: Translation.tr("Dismiss Orbit before launching a pinned shell action")
                checked: root.shelfOptions.closeOnAction ?? true
                onCheckedChanged: Config.setNestedValue("orbit.shelf.closeOnAction", checked)
            }

            ColumnLayout {
                Layout.fillWidth: true
                enabled: (root.shelfOptions.enable ?? true)
                    && root.shelfModules.includes("actions")
                spacing: 8

                StyledText {
                    text: Translation.tr("Pinned actions")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Choose any built-in or custom Global Action. The Shelf also keeps an All actions button.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: 3

                    delegate: RowLayout {
                        id: actionSlot
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10

                        StyledText {
                            Layout.preferredWidth: 72
                            text: Translation.tr("Slot %1").arg(actionSlot.index + 1)
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }

                        StyledComboBox {
                            Layout.fillWidth: true
                            model: root.actionOptions
                            textRole: "displayName"
                            currentIndex: root.actionChoiceIndex(root.pinnedAction(actionSlot.index))
                            settingsSearchLabel: Translation.tr("Orbit pinned action %1").arg(actionSlot.index + 1)
                            settingsSearchDescription: Translation.tr("Action launched from the Orbit Shelf")
                            onActivated: index => {
                                if (index >= 0 && index < root.actionOptions.length)
                                    root.setPinnedAction(actionSlot.index, root.actionOptions[index].value)
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "motion"
        visible: root.activeSection === "motion"
        expanded: true
        icon: "animation"
        title: Translation.tr("Material motion")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Entry motion")

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.motionStyle ?? "spring"
                    onSelected: value => Config.setNestedValue("orbit.motionStyle", value)
                    options: [
                        { displayName: Translation.tr("Spring"), icon: "motion_photos_on", value: "spring" },
                        { displayName: Translation.tr("Glide"), icon: "east", value: "glide" },
                        { displayName: Translation.tr("Instant"), icon: "bolt", value: "instant" }
                    ]
                }
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                icon: "contrast"
                text: Translation.tr("Backdrop dim")
                value: root.orbitOptions.scrimDim ?? 35
                from: 0
                to: 80
                stepSize: 5
                onValueChanged: Config.setNestedValue("orbit.scrimDim", value)
            }

            ConfigSwitch {
                text: Translation.tr("Workspace numbers")
                checked: root.orbitOptions.showWorkspaceNumbers ?? true
                onCheckedChanged: Config.setNestedValue("orbit.showWorkspaceNumbers", checked)
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Colors, typography, rounding, shadows and reduced-motion policy always follow the active Material appearance.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }
}
